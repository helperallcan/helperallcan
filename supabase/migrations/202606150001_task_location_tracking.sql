create table if not exists public.task_locations (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  latitude numeric(9,6) not null check (latitude between -90 and 90),
  longitude numeric(9,6) not null check (longitude between -180 and 180),
  accuracy_meters numeric(10,2) check (accuracy_meters is null or accuracy_meters >= 0),
  heading_degrees numeric(6,2) check (heading_degrees is null or heading_degrees between 0 and 360),
  speed_mps numeric(10,2) check (speed_mps is null or speed_mps >= 0),
  sharing_status text not null default 'active' check (sharing_status in ('active', 'paused', 'arrived')),
  source text not null default 'manual' check (source in ('manual', 'device', 'system')),
  label text check (label is null or char_length(label) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(task_id, user_id)
);

drop trigger if exists task_locations_set_updated_at on public.task_locations;
create trigger task_locations_set_updated_at before update on public.task_locations
for each row execute function public.set_updated_at();

create index if not exists task_locations_task_updated_idx
on public.task_locations(task_id, updated_at desc);

create index if not exists task_locations_user_idx
on public.task_locations(user_id);

create or replace function public.can_view_task_tracking(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and (
        public.is_admin()
        or t.creator_id = auth.uid()
        or t.assigned_helper_id = auth.uid()
      )
      and t.status in ('assigned', 'in_progress', 'completed')
  )
$$;

create or replace function public.can_share_task_location(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and (
        t.creator_id = auth.uid()
        or t.assigned_helper_id = auth.uid()
      )
      and t.status in ('assigned', 'in_progress')
      and public.is_active_user(auth.uid())
  )
$$;

alter table public.task_locations enable row level security;

drop policy if exists "Task parties can view task tracking" on public.task_locations;
create policy "Task parties can view task tracking"
on public.task_locations for select
to authenticated
using (public.can_view_task_tracking(task_id));

drop policy if exists "Task parties can share own task location" on public.task_locations;
create policy "Task parties can share own task location"
on public.task_locations for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.can_share_task_location(task_id)
);

drop policy if exists "Task parties can update own task location" on public.task_locations;
create policy "Task parties can update own task location"
on public.task_locations for update
to authenticated
using (
  user_id = auth.uid()
  and public.can_share_task_location(task_id)
)
with check (
  user_id = auth.uid()
  and public.can_share_task_location(task_id)
);

drop policy if exists "Task parties can delete own task location" on public.task_locations;
create policy "Task parties can delete own task location"
on public.task_locations for delete
to authenticated
using (user_id = auth.uid() or public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.task_locations;
exception when duplicate_object then null;
end $$;
