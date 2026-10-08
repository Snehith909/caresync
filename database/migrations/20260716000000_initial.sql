create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  role text not null default 'doctor' check (role = 'doctor'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  name text not null check (length(trim(name)) between 1 and 160),
  age smallint not null check (age between 0 and 125),
  gender text not null check (length(trim(gender)) between 1 and 80),
  condition text not null check (length(trim(condition)) between 1 and 500),
  phone text not null check (length(trim(phone)) between 1 and 40),
  nominee text not null default '',
  nominee_relation text not null default '',
  follow_up date,
  adherence_percent smallint check (adherence_percent between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, doctor_id)
);

create table public.care_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  doctor_id uuid not null references public.profiles (user_id),
  version integer not null check (version > 0),
  status text not null default 'pending_review'
    check (status in ('pending_review', 'active', 'correction_requested', 'rejected', 'superseded')),
  notes text not null check (length(trim(notes)) between 1 and 10000),
  source_path text not null,
  medications jsonb not null check (jsonb_typeof(medications) = 'array'),
  is_reassessment boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (patient_id, version),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  doctor_id uuid not null references public.profiles (user_id),
  reason text not null check (length(trim(reason)) between 1 and 240),
  detail text not null default '',
  severity text not null check (severity in ('urgent', 'warning', 'info')),
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  action text not null,
  entity_type text not null,
  entity_id uuid not null,
  created_at timestamptz not null default now()
);

create index patients_doctor_created_idx on public.patients (doctor_id, created_at desc);
create index care_plans_doctor_created_idx on public.care_plans (doctor_id, created_at desc);
create index care_plans_patient_version_idx on public.care_plans (patient_id, version desc);
create index alerts_doctor_created_idx on public.alerts (doctor_id, created_at desc);
create index alerts_open_idx on public.alerts (doctor_id, status) where status = 'open';
create index audit_events_doctor_created_idx on public.audit_events (doctor_id, created_at desc);

create function public.is_active_doctor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where user_id = (select auth.uid()) and role = 'doctor' and active
  );
$$;

revoke all on function public.is_active_doctor() from public;
grant execute on function public.is_active_doctor() to authenticated;

alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.care_plans enable row level security;
alter table public.alerts enable row level security;
alter table public.audit_events enable row level security;

create policy "Doctors read their own profile"
on public.profiles for select to authenticated
using (user_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors read assigned patients"
on public.patients for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors create assigned patients"
on public.patients for insert to authenticated
with check (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors update assigned patients"
on public.patients for update to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor())
with check (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors read assigned care plans"
on public.care_plans for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors read assigned alerts"
on public.alerts for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Doctors read their audit events"
on public.audit_events for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

grant select on public.profiles to authenticated;
grant select, insert, update on public.patients to authenticated;
grant select on public.care_plans, public.alerts, public.audit_events to authenticated;
revoke all on public.profiles, public.patients, public.care_plans, public.alerts, public.audit_events from public, anon;

create function public.log_patient_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_events (doctor_id, action, entity_type, entity_id)
  values (new.doctor_id, case when tg_op = 'INSERT' then 'patient.created' else 'patient.updated' end, 'patient', new.id);
  return new;
end;
$$;

create trigger patients_audit_trigger
after insert or update on public.patients
for each row execute function public.log_patient_change();

revoke all on function public.log_patient_change() from public, anon, authenticated;

create function public.create_care_plan_draft(
  p_patient_id uuid,
  p_notes text,
  p_source_path text,
  p_medications jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctor_id uuid := (select auth.uid());
  v_plan_id uuid;
  v_version integer;
  v_medication jsonb;
begin
  if not public.is_active_doctor() then
    raise exception 'An active doctor account is required.';
  end if;
  perform 1 from public.patients where id = p_patient_id and doctor_id = v_doctor_id for update;
  if not found then
    raise exception 'Patient not found or access denied.';
  end if;
  if length(trim(coalesce(p_notes, ''))) = 0 or length(p_notes) > 10000 then
    raise exception 'Reassessment notes are required and must be 10,000 characters or fewer.';
  end if;
  if p_source_path not like (v_doctor_id::text || '/' || p_patient_id::text || '/%') then
    raise exception 'The source document path is invalid.';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'care-plan-documents' and name = p_source_path
      and split_part(name, '/', 1) = v_doctor_id::text
      and split_part(name, '/', 2) = p_patient_id::text
  ) then
    raise exception 'The uploaded source document was not found for this patient.';
  end if;
  if jsonb_typeof(p_medications) <> 'array' or jsonb_array_length(p_medications) = 0 then
    raise exception 'At least one medication entry is required.';
  end if;
  for v_medication in select value from jsonb_array_elements(p_medications)
  loop
    if length(trim(coalesce(v_medication->>'name', ''))) = 0
      or length(trim(coalesce(v_medication->>'strength', ''))) = 0
      or length(trim(coalesce(v_medication->>'directions', ''))) = 0 then
      raise exception 'Each medication requires a name, strength, and directions.';
    end if;
  end loop;

  select coalesce(max(version), 0) + 1 into v_version
  from public.care_plans where patient_id = p_patient_id;

  insert into public.care_plans (patient_id, doctor_id, version, notes, source_path, medications)
  values (p_patient_id, v_doctor_id, v_version, trim(p_notes), p_source_path, p_medications)
  returning id into v_plan_id;

  insert into public.audit_events (doctor_id, action, entity_type, entity_id)
  values (v_doctor_id, 'care_plan.created', 'care_plan', v_plan_id);
  return v_plan_id;
end;
$$;

create function public.act_on_care_plan(p_plan_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctor_id uuid := (select auth.uid());
  v_plan public.care_plans%rowtype;
begin
  if not public.is_active_doctor() then
    raise exception 'An active doctor account is required.';
  end if;
  if p_action not in ('approve', 'correction', 'reject') then
    raise exception 'Unsupported care plan action.';
  end if;
  select * into v_plan from public.care_plans
  where id = p_plan_id and doctor_id = v_doctor_id for update;
  if not found or v_plan.status <> 'pending_review' then
    raise exception 'Care plan not found or no longer awaiting review.';
  end if;
  if p_action = 'approve' and (v_plan.source_path = '' or jsonb_array_length(v_plan.medications) = 0) then
    raise exception 'A source document and medication details are required before approval.';
  end if;

  if p_action = 'approve' then
    update public.care_plans set status = 'superseded', updated_at = now()
    where patient_id = v_plan.patient_id and doctor_id = v_doctor_id and status = 'active';
    update public.care_plans set status = 'active', updated_at = now() where id = p_plan_id;
  else
    update public.care_plans
    set status = case when p_action = 'correction' then 'correction_requested' else 'rejected' end,
        updated_at = now()
    where id = p_plan_id;
  end if;

  insert into public.audit_events (doctor_id, action, entity_type, entity_id)
  values (v_doctor_id, 'care_plan.' || p_action, 'care_plan', p_plan_id);
end;
$$;

create function public.acknowledge_alert(p_alert_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctor_id uuid := (select auth.uid());
begin
  if not public.is_active_doctor() then
    raise exception 'An active doctor account is required.';
  end if;
  update public.alerts set status = 'acknowledged', updated_at = now()
  where id = p_alert_id and doctor_id = v_doctor_id and status = 'open';
  if not found then
    raise exception 'Alert not found or no longer open.';
  end if;
  insert into public.audit_events (doctor_id, action, entity_type, entity_id)
  values (v_doctor_id, 'alert.acknowledged', 'alert', p_alert_id);
end;
$$;

revoke all on function public.create_care_plan_draft(uuid, text, text, jsonb) from public;
revoke all on function public.act_on_care_plan(uuid, text) from public;
revoke all on function public.acknowledge_alert(uuid) from public;
grant execute on function public.create_care_plan_draft(uuid, text, text, jsonb) to authenticated;
grant execute on function public.act_on_care_plan(uuid, text) to authenticated;
grant execute on function public.acknowledge_alert(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('care-plan-documents', 'care-plan-documents', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];

create policy "Doctors read assigned care plan documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'care-plan-documents'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and exists (
    select 1 from public.patients
    where id::text = split_part(name, '/', 2) and doctor_id = (select auth.uid())
  )
);

create policy "Doctors upload assigned care plan documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'care-plan-documents'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and exists (
    select 1 from public.patients
    where id::text = split_part(name, '/', 2) and doctor_id = (select auth.uid())
  )
);

create policy "Doctors remove their failed uploads"
on storage.objects for delete to authenticated
using (
  bucket_id = 'care-plan-documents'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and exists (
    select 1 from public.patients
    where id::text = split_part(name, '/', 2) and doctor_id = (select auth.uid())
  )
  and not exists (
    select 1 from public.care_plans where source_path = name
  )
);
