create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'checked_in', 'in_consultation', 'completed', 'cancelled', 'no_show')),
  reason text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (id, doctor_id),
  unique (id, patient_id, doctor_id),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.queue_entries (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  appointment_id uuid,
  queue_date date not null default current_date,
  token_number integer not null check (token_number > 0),
  status text not null default 'waiting'
    check (status in ('waiting', 'consulting', 'completed', 'cancelled')),
  checked_in_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (doctor_id, queue_date, token_number),
  unique (id, doctor_id),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id),
  foreign key (appointment_id, patient_id, doctor_id)
    references public.appointments (id, patient_id, doctor_id)
);

create table public.consultations (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  appointment_id uuid,
  queue_entry_id uuid,
  symptoms text not null default '',
  notes text not null default '',
  diagnosis text not null default '',
  treatment_plan text not null default '',
  follow_up_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, doctor_id),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id),
  foreign key (appointment_id, patient_id, doctor_id)
    references public.appointments (id, patient_id, doctor_id),
  foreign key (queue_entry_id, doctor_id) references public.queue_entries (id, doctor_id)
);

create table public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  consultation_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, doctor_id),
  foreign key (consultation_id, doctor_id) references public.consultations (id, doctor_id)
);

create table public.medications (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  prescription_id uuid not null,
  name text not null check (length(trim(name)) between 1 and 200),
  dosage text not null check (length(trim(dosage)) between 1 and 200),
  frequency text not null check (length(trim(frequency)) between 1 and 200),
  duration text not null check (length(trim(duration)) between 1 and 200),
  instructions text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (prescription_id, doctor_id) references public.prescriptions (id, doctor_id)
);

create table public.lab_reports (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  storage_path text not null,
  report_type text not null default '',
  status text not null default 'uploaded'
    check (status in ('uploaded', 'processing', 'reviewed', 'failed')),
  extracted_values jsonb not null default '[]'::jsonb
    check (jsonb_typeof(extracted_values) = 'array'),
  abnormal_flags jsonb not null default '[]'::jsonb
    check (jsonb_typeof(abnormal_flags) = 'array'),
  collected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.vitals (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  measured_at timestamptz not null default now(),
  systolic integer check (systolic between 30 and 300),
  diastolic integer check (diastolic between 20 and 200),
  heart_rate integer check (heart_rate between 20 and 300),
  temperature_c numeric(4, 1) check (temperature_c between 25 and 45),
  respiratory_rate integer check (respiratory_rate between 1 and 100),
  oxygen_saturation numeric(4, 1) check (oxygen_saturation between 0 and 100),
  weight_kg numeric(6, 2) check (weight_kg > 0),
  height_cm numeric(6, 2) check (height_cm > 0),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.allergies (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  substance text not null check (length(trim(substance)) between 1 and 200),
  reaction text not null default '',
  severity text not null default 'unknown'
    check (severity in ('unknown', 'mild', 'moderate', 'severe')),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.medical_history (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  category text not null check (length(trim(category)) between 1 and 100),
  description text not null check (length(trim(description)) between 1 and 10000),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create table public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid not null,
  consultation_id uuid,
  due_at timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'completed', 'cancelled', 'overdue')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id),
  foreign key (consultation_id, doctor_id) references public.consultations (id, doctor_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles (user_id),
  patient_id uuid,
  kind text not null check (kind in ('appointment_reminder', 'follow_up_reminder', 'queue_update', 'other')),
  title text not null check (length(trim(title)) between 1 and 200),
  body text not null default '',
  scheduled_at timestamptz,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (patient_id, doctor_id) references public.patients (id, doctor_id)
);

create index appointments_doctor_schedule_idx on public.appointments (doctor_id, starts_at);
create index appointments_patient_schedule_idx on public.appointments (patient_id, starts_at desc);
create index queue_entries_doctor_position_idx on public.queue_entries (doctor_id, queue_date, status, token_number);
create unique index queue_entries_one_consulting_idx
  on public.queue_entries (doctor_id, queue_date) where status = 'consulting';
create index queue_entries_appointment_idx on public.queue_entries (appointment_id);
create index consultations_patient_history_idx on public.consultations (patient_id, created_at desc);
create index consultations_appointment_idx on public.consultations (appointment_id);
create index consultations_queue_entry_idx on public.consultations (queue_entry_id);
create index prescriptions_consultation_idx on public.prescriptions (consultation_id, created_at desc);
create index medications_prescription_idx on public.medications (prescription_id);
create index lab_reports_patient_created_idx on public.lab_reports (patient_id, created_at desc);
create index vitals_patient_measured_idx on public.vitals (patient_id, measured_at desc);
create index allergies_patient_idx on public.allergies (patient_id);
create index medical_history_patient_recorded_idx on public.medical_history (patient_id, recorded_at desc);
create index follow_ups_doctor_due_idx on public.follow_ups (doctor_id, due_at, status);
create index follow_ups_consultation_idx on public.follow_ups (consultation_id);
create index notifications_doctor_created_idx on public.notifications (doctor_id, created_at desc);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function public.log_clinical_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_doctor_id uuid := (v_row ->> 'doctor_id')::uuid;
  v_entity_id uuid := (v_row ->> 'id')::uuid;
begin
  insert into public.audit_events (doctor_id, action, entity_type, entity_id)
  values (v_doctor_id, lower(tg_table_name) || '.' || lower(tg_op), lower(tg_table_name), v_entity_id);
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.log_clinical_change() from public, anon, authenticated;

do $$
declare
  v_table text;
  v_tables text[] := array[
    'appointments', 'queue_entries', 'consultations', 'prescriptions', 'medications',
    'lab_reports', 'vitals', 'allergies', 'medical_history', 'follow_ups', 'notifications'
  ];
begin
  foreach v_table in array v_tables loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format(
      'create policy "Doctors manage own %1$s" on public.%1$I for all to authenticated using (doctor_id = (select auth.uid()) and public.is_active_doctor()) with check (doctor_id = (select auth.uid()) and public.is_active_doctor())',
      v_table
    );
    execute format('grant select, insert, update on public.%I to authenticated', v_table);
    execute format('revoke all on public.%I from public, anon', v_table);
    execute format(
      'create trigger %1$s_set_updated_at before update on public.%1$I for each row execute function public.set_updated_at()',
      v_table
    );
    execute format(
      'create trigger %1$s_audit after insert or update on public.%1$I for each row execute function public.log_clinical_change()',
      v_table
    );
  end loop;
end;
$$;
