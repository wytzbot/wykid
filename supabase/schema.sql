-- Writing Kids recurring Premium subscriptions.
-- Run this once in Supabase SQL Editor.
create table if not exists public.writing_kids_subscriptions (
  email text primary key,
  customer_id text not null,
  payment_method_id text not null,
  reference text,
  amount numeric(12,2) not null,
  currency text not null check (currency in ('USD','NGN')),
  status text not null default 'active',
  next_charge_at timestamptz not null,
  last_charge_reference text,
  last_status text,
  fail_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Existing installs created before fail_count existed: add it without losing data.
alter table public.writing_kids_subscriptions
  add column if not exists fail_count integer not null default 0;

create index if not exists writing_kids_subscriptions_due_idx
  on public.writing_kids_subscriptions (status, next_charge_at);

alter table public.writing_kids_subscriptions enable row level security;

-- No client policy is created. The Vercel API uses the Supabase service-role key
-- and therefore bypasses RLS. Never expose that key in Flutter/web client code.

create or replace function public.writing_kids_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists writing_kids_subscriptions_updated_at on public.writing_kids_subscriptions;
create trigger writing_kids_subscriptions_updated_at
before update on public.writing_kids_subscriptions
for each row execute function public.writing_kids_set_updated_at();
