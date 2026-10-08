-- Patient mobile integration for the existing doctor-owned schema.
-- This migration is additive and preserves doctor care-plan versioning.

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('patient', 'doctor', 'hospital_admin'));

create or replace function public.create_patient_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name, role, active)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'CareSync patient'
    ),
    'patient',
    true
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_patient_profile on auth.users;
create trigger on_auth_user_created_patient_profile
after insert on auth.users
for each row execute function public.create_patient_profile();
revoke all on function public.create_patient_profile() from public, anon, authenticated;

alter table public.patients
  add column if not exists patient_user_id uuid references auth.users (id) on delete set null;

create unique index if not exists patients_patient_user_id_idx
  on public.patients (patient_user_id)
  where patient_user_id is not null;

create index if not exists patients_patient_user_id_lookup_idx
  on public.patients (patient_user_id);

create table if not exists public.medication_adherence (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  doctor_id uuid not null references public.profiles (user_id),
  care_plan_id uuid references public.care_plans (id),
  medicine_key text not null check (length(trim(medicine_key)) between 1 and 200),
  scheduled_for timestamptz not null,
  status text not null check (status in ('taken', 'missed')),
  recorded_by uuid not null references auth.users (id),
  recorded_at timestamptz not null default now(),
  unique (patient_id, medicine_key, scheduled_for),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create index if not exists medication_adherence_doctor_time_idx
  on public.medication_adherence (doctor_id, scheduled_for desc);
create index if not exists medication_adherence_patient_time_idx
  on public.medication_adherence (patient_id, scheduled_for desc);

alter table public.medication_adherence enable row level security;

create policy "Doctors read assigned adherence"
on public.medication_adherence for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Patients read own adherence"
on public.medication_adherence for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = medication_adherence.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients record own adherence"
on public.medication_adherence for insert to authenticated
with check (
  recorded_by = (select auth.uid())
  and exists (
    select 1 from public.patients p
    where p.id = medication_adherence.patient_id
      and p.patient_user_id = (select auth.uid())
      and p.doctor_id = medication_adherence.doctor_id
  )
);

create policy "Patients correct own adherence"
on public.medication_adherence for update to authenticated
using (
  recorded_by = (select auth.uid())
  and exists (
    select 1 from public.patients p
    where p.id = medication_adherence.patient_id
      and p.patient_user_id = (select auth.uid())
  )
)
with check (recorded_by = (select auth.uid()));

grant select on public.medication_adherence to authenticated;
grant insert, update on public.medication_adherence to authenticated;
revoke all on public.medication_adherence from anon, public;

create or replace function public.record_medication_adherence(
  p_patient_id uuid,
  p_care_plan_id uuid,
  p_medicine_key text,
  p_scheduled_for timestamptz,
  p_status text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctor_id uuid;
  v_id uuid;
begin
  if p_status not in ('taken', 'missed') then
    raise exception 'Unsupported adherence status.';
  end if;

  select doctor_id into v_doctor_id
  from public.patients
  where id = p_patient_id and patient_user_id = (select auth.uid());
  if not found then
    raise exception 'Patient not found or access denied.';
  end if;

  insert into public.medication_adherence (
    patient_id, doctor_id, care_plan_id, medicine_key,
    scheduled_for, status, recorded_by
  )
  values (
    p_patient_id, v_doctor_id, p_care_plan_id, trim(p_medicine_key),
    p_scheduled_for, p_status, (select auth.uid())
  )
  on conflict (patient_id, medicine_key, scheduled_for)
  do update set status = excluded.status, recorded_at = now()
  returning id into v_id;

  if p_status = 'missed' then
    insert into public.alerts (patient_id, doctor_id, reason, detail, severity)
    values (
      p_patient_id, v_doctor_id, 'Missed medication',
      'A patient medication event was marked as missed.',
      'warning'
    );
  end if;
  return v_id;
end;
$$;

revoke all on function public.record_medication_adherence(uuid, uuid, text, timestamptz, text)
  from public, anon;
grant execute on function public.record_medication_adherence(uuid, uuid, text, timestamptz, text)
  to authenticated;

create table if not exists public.patient_documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  doctor_id uuid not null references public.profiles (user_id),
  storage_path text not null unique,
  document_type text not null default 'prescription',
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id),
  check (storage_path like ('patients/' || patient_id::text || '/%'))
);

create index if not exists patient_documents_patient_created_idx
  on public.patient_documents (patient_id, created_at desc);

alter table public.patient_documents enable row level security;

create policy "Doctors read assigned patient documents"
on public.patient_documents for select to authenticated
using (doctor_id = (select auth.uid()) and public.is_active_doctor());

create policy "Patients read own documents"
on public.patient_documents for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = patient_documents.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

grant select on public.patient_documents to authenticated;
revoke all on public.patient_documents from anon, public;

create function public.register_patient_document(
  p_patient_id uuid,
  p_storage_path text,
  p_document_type text default 'prescription'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctor_id uuid;
  v_id uuid;
begin
  select doctor_id into v_doctor_id
  from public.patients
  where id = p_patient_id and patient_user_id = (select auth.uid());
  if not found then
    raise exception 'Patient not found or access denied.';
  end if;
  if p_storage_path <> ('patients/' || p_patient_id::text || '/')
     and p_storage_path not like ('patients/' || p_patient_id::text || '/%') then
    raise exception 'The document path is invalid.';
  end if;
  insert into public.patient_documents (
    patient_id, doctor_id, storage_path, document_type, created_by
  )
  values (
    p_patient_id, v_doctor_id, p_storage_path, coalesce(nullif(trim(p_document_type), ''), 'prescription'),
    (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.register_patient_document(uuid, text, text)
  from public, anon;
grant execute on function public.register_patient_document(uuid, text, text)
  to authenticated;

create function public.update_patient_condition(
  p_patient_id uuid,
  p_condition text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if length(trim(coalesce(p_condition, ''))) = 0
     or length(p_condition) > 500 then
    raise exception 'Condition is required and must be 500 characters or fewer.';
  end if;
  update public.patients
  set condition = trim(p_condition), updated_at = now()
  where id = p_patient_id and patient_user_id = (select auth.uid());
  if not found then
    raise exception 'Patient not found or access denied.';
  end if;
end;
$$;

revoke all on function public.update_patient_condition(uuid, text)
  from public, anon;
grant execute on function public.update_patient_condition(uuid, text)
  to authenticated;

create policy "Patients upload own documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'care-plan-documents'
  and name like ('patients/' || (
    select p.id::text from public.patients p
    where p.patient_user_id = (select auth.uid())
  ) || '/%')
);

create policy "Patients read own documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'care-plan-documents'
  and name like ('patients/' || (
    select p.id::text from public.patients p
    where p.patient_user_id = (select auth.uid())
  ) || '/%')
);

create policy "Doctors read patient uploaded documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'care-plan-documents'
  and split_part(name, '/', 1) = 'patients'
  and exists (
    select 1
    from public.patients p
    where p.id::text = split_part(name, '/', 2)
      and p.doctor_id = (select auth.uid())
      and public.is_active_doctor()
  )
);

create policy "Patients delete own unlinked documents"
on storage.objects for delete to authenticated
using (
  bucket_id = 'care-plan-documents'
  and name like ('patients/' || (
    select p.id::text from public.patients p
    where p.patient_user_id = (select auth.uid())
  ) || '/%')
  and not exists (
    select 1 from public.patient_documents d where d.storage_path = name
  )
);

create policy "Patients read own profile"
on public.profiles for select to authenticated
using (user_id = (select auth.uid()) and role = 'patient');

create policy "Patients read own patient record"
on public.patients for select to authenticated
using (patient_user_id = (select auth.uid()));

create policy "Patients read own care plans"
on public.care_plans for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = care_plans.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own alerts"
on public.alerts for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = alerts.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

grant select on public.patients, public.care_plans, public.alerts to authenticated;

create policy "Patients read own appointments"
on public.appointments for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = appointments.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own consultations"
on public.consultations for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = consultations.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own prescriptions"
on public.prescriptions for select to authenticated
using (
  exists (
    select 1
    from public.consultations c
    join public.patients p on p.id = c.patient_id
    where c.id = prescriptions.consultation_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own medications"
on public.medications for select to authenticated
using (
  exists (
    select 1
    from public.prescriptions rx
    join public.consultations c on c.id = rx.consultation_id
    join public.patients p on p.id = c.patient_id
    where rx.id = medications.prescription_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own lab reports"
on public.lab_reports for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = lab_reports.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own vitals"
on public.vitals for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = vitals.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own allergies"
on public.allergies for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = allergies.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own medical history"
on public.medical_history for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = medical_history.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own follow ups"
on public.follow_ups for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = follow_ups.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);

create policy "Patients read own notifications"
on public.notifications for select to authenticated
using (
  exists (
    select 1 from public.patients p
    where p.id = notifications.patient_id
      and p.patient_user_id = (select auth.uid())
  )
);
