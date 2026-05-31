alter table public.tasks
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancellation_reason text,
  add column if not exists expires_at timestamptz not null default (now() + interval '30 days');

create index if not exists tasks_expires_at_idx
on public.tasks(expires_at)
where status in ('open', 'offered');

create or replace function public.cancel_task(
  p_task_id uuid,
  p_reason text default null
)
returns public.task_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
begin
  perform set_config('app.bypass_task_guard', 'on', true);
  perform set_config('app.bypass_offer_guard', 'on', true);

  select * into v_task
  from public.tasks
  where id = p_task_id
  for update;

  if not found then
    raise exception 'Task not found.';
  end if;

  if v_task.creator_id <> auth.uid() and not public.is_admin() then
    raise exception 'Only task owner can cancel a task.';
  end if;

  if v_task.status in ('completed', 'cancelled', 'hidden', 'rejected') then
    raise exception 'Task cannot be cancelled from its current status.';
  end if;

  update public.task_offers
  set status = 'rejected'
  where task_id = p_task_id
    and status in ('pending', 'accepted');

  update public.conversations
  set status = 'closed'
  where task_id = p_task_id;

  update public.tasks
  set status = 'cancelled',
      assigned_helper_id = null,
      selected_offer_id = null,
      cancelled_at = now(),
      cancellation_reason = nullif(trim(p_reason), '')
  where id = p_task_id;

  if v_task.assigned_helper_id is not null then
    insert into public.notifications (user_id, notification_type, title, body, data)
    values (
      v_task.assigned_helper_id,
      'task',
      '任务已取消',
      '发布者取消了任务，相关聊天已关闭。',
      jsonb_build_object('task_id', p_task_id)
    );
  end if;

  return 'cancelled'::public.task_status;
end;
$$;

create or replace function public.reopen_task_for_offers(
  p_task_id uuid,
  p_reason text default null
)
returns public.task_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_next_status public.task_status;
begin
  perform set_config('app.bypass_task_guard', 'on', true);
  perform set_config('app.bypass_offer_guard', 'on', true);

  select * into v_task
  from public.tasks
  where id = p_task_id
  for update;

  if not found then
    raise exception 'Task not found.';
  end if;

  if v_task.creator_id <> auth.uid() and not public.is_admin() then
    raise exception 'Only task owner can reopen a task.';
  end if;

  if v_task.status not in ('assigned', 'in_progress') then
    raise exception 'Only assigned or in-progress tasks can be reopened.';
  end if;

  if v_task.selected_offer_id is not null then
    update public.task_offers
    set status = 'rejected'
    where id = v_task.selected_offer_id
      and status = 'accepted';
  end if;

  update public.conversations
  set status = 'closed'
  where task_id = p_task_id;

  select case
    when exists (
      select 1 from public.task_offers
      where task_id = p_task_id and status = 'pending'
    )
    then 'offered'::public.task_status
    else 'open'::public.task_status
  end into v_next_status;

  update public.tasks
  set status = v_next_status,
      assigned_helper_id = null,
      selected_offer_id = null,
      completion_note = null,
      completion_proof_url = null
  where id = p_task_id;

  if v_task.assigned_helper_id is not null then
    insert into public.notifications (user_id, notification_type, title, body, data)
    values (
      v_task.assigned_helper_id,
      'task',
      '任务已重新开放',
      coalesce(nullif(trim(p_reason), ''), '发布者已重新开放任务，将重新选择帮手。'),
      jsonb_build_object('task_id', p_task_id)
    );
  end if;

  return v_next_status;
end;
$$;

create or replace function public.withdraw_task_offer(p_offer_id uuid)
returns public.offer_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.task_offers%rowtype;
  v_task public.tasks%rowtype;
begin
  perform set_config('app.bypass_task_guard', 'on', true);
  perform set_config('app.bypass_offer_guard', 'on', true);

  select * into v_offer
  from public.task_offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'Offer not found.';
  end if;

  if v_offer.helper_id <> auth.uid() then
    raise exception 'Only offer owner can withdraw an offer.';
  end if;

  if v_offer.status <> 'pending' then
    raise exception 'Only pending offers can be withdrawn.';
  end if;

  select * into v_task
  from public.tasks
  where id = v_offer.task_id
  for update;

  if not found or v_task.status not in ('open', 'offered') then
    raise exception 'Task is not open for withdrawing offers.';
  end if;

  update public.task_offers
  set status = 'withdrawn'
  where id = p_offer_id;

  if not exists (
    select 1 from public.task_offers
    where task_id = v_offer.task_id
      and status = 'pending'
  ) then
    update public.tasks
    set status = 'open'
    where id = v_offer.task_id
      and status = 'offered';
  end if;

  insert into public.notifications (user_id, notification_type, title, body, data)
  values (
    v_task.creator_id,
    'offer',
    '帮手已撤回报价',
    '一位帮手撤回了报价，你可以继续等待其他报价。',
    jsonb_build_object('task_id', v_offer.task_id, 'offer_id', p_offer_id)
  );

  return 'withdrawn'::public.offer_status;
end;
$$;

create or replace function public.expire_open_tasks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if not public.is_service_role() and not public.is_admin() then
    raise exception 'Admin only.';
  end if;

  perform set_config('app.bypass_task_guard', 'on', true);
  perform set_config('app.bypass_offer_guard', 'on', true);

  update public.task_offers o
  set status = 'rejected'
  from public.tasks t
  where o.task_id = t.id
    and t.status in ('open', 'offered')
    and t.expires_at <= now()
    and o.status = 'pending';

  update public.tasks
  set status = 'cancelled',
      cancelled_at = now(),
      cancellation_reason = coalesce(cancellation_reason, 'Expired automatically')
  where status in ('open', 'offered')
    and expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.cancel_task(uuid, text) to authenticated;
grant execute on function public.reopen_task_for_offers(uuid, text) to authenticated;
grant execute on function public.withdraw_task_offer(uuid) to authenticated;
grant execute on function public.expire_open_tasks() to authenticated;
