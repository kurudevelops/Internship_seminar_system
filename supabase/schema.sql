create extension if not exists "pgcrypto";

drop table if exists public.seminar_attendees cascade;

create table public.seminar_attendees (
    id uuid default gen_random_uuid() primary key,
    student_id text unique not null,
    full_name text not null,
    email text unique not null,
    program_section text not null,
    registration_type text not null default 'PRE_REGISTERED'
        check (registration_type in ('PRE_REGISTERED', 'WALK_IN')),
    is_present boolean not null default false,
    time_in timestamptz,
    is_paid boolean not null default false,
    amount_paid numeric(10, 2) not null default 0.00,
    payment_method text not null default 'NONE'
        check (payment_method in ('NONE', 'CASH', 'GCASH')),
    paid_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index idx_seminar_attendees_student_id on public.seminar_attendees (student_id);
create index idx_seminar_attendees_email on public.seminar_attendees (email);
create index idx_seminar_attendees_reg_type on public.seminar_attendees (registration_type);
create index idx_seminar_attendees_is_present on public.seminar_attendees (is_present);
create index idx_seminar_attendees_is_paid on public.seminar_attendees (is_paid);

create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger trg_seminar_attendees_updated_at
before update on public.seminar_attendees
for each row
execute function public.set_updated_at();

alter table public.seminar_attendees enable row level security;

-- Seed Data for immediate testing across Entrance, Admin, and Finance
insert into public.seminar_attendees (
    student_id, full_name, email, program_section,
    registration_type, is_present, time_in, is_paid, amount_paid, payment_method, paid_at
) values
    ('2230001', 'Dela Cruz, Juan A.', '2230001@slu.edu.ph', 'BSCS 3A', 'PRE_REGISTERED', true, now(), true, 150.00, 'GCASH', now()),
    ('2230002', 'Santos, Maria Clara B.', '2230002@slu.edu.ph', 'BSCS 3B', 'PRE_REGISTERED', false, null, true, 150.00, 'GCASH', now()),
    ('2230003', 'Reyes, Jose P.', '2230003@slu.edu.ph', 'BSIT 3A', 'PRE_REGISTERED', false, null, false, 0.00, 'NONE', null),
    ('2230004', 'Mendoza, Karl S.', '2230004@slu.edu.ph', 'BSCS 3A', 'WALK_IN', true, now(), true, 150.00, 'CASH', now())
on conflict (student_id) do nothing;