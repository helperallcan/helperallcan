create or replace function public.notify_task_location_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_recipient_id uuid;
  v_sender_name text;
  v_title text;
  v_body text;
  v_route_path text;
  v_recent_exists boolean;
begin
  select * into v_task
  from public.tasks
  where id = new.task_id;

  if not found or v_task.status not in ('assigned', 'in_progress') then
    return new;
  end if;

  if new.user_id = v_task.creator_id then
    v_recipient_id := v_task.assigned_helper_id;
  elsif new.user_id = v_task.assigned_helper_id then
    v_recipient_id := v_task.creator_id;
  else
    return new;
  end if;

  if v_recipient_id is null or v_recipient_id = new.user_id then
    return new;
  end if;

  select exists (
    select 1
    from public.notifications n
    where n.user_id = v_recipient_id
      and n.notification_type = 'task'
      and n.data->>'event' = 'task_location_update'
      and n.data->>'task_id' = new.task_id::text
      and n.data->>'sender_id' = new.user_id::text
      and n.created_at > now() - interval '10 minutes'
  ) into v_recent_exists;

  if tg_op = 'UPDATE'
    and new.sharing_status is not distinct from old.sharing_status
    and v_recent_exists
  then
    return new;
  end if;

  select display_name into v_sender_name
  from public.profiles
  where id = new.user_id;

  v_route_path := '/tasks/' || new.task_id::text || '/tracking';

  if new.sharing_status = 'arrived' then
    v_title := '对方已到达';
    v_body := coalesce(v_sender_name, '对方') || '已标记到达，可以打开地图确认位置。';
  elsif new.sharing_status = 'paused' then
    v_title := '对方暂停位置共享';
    v_body := coalesce(v_sender_name, '对方') || '暂停了本次任务的位置共享。';
  else
    v_title := '任务位置已更新';
    v_body := coalesce(v_sender_name, '对方') || '共享了当前位置，可以打开地图追踪。';
  end if;

  insert into public.notifications (user_id, notification_type, title, body, data)
  values (
    v_recipient_id,
    'task',
    v_title,
    v_body,
    jsonb_build_object(
      'event', 'task_location_update',
      'task_id', new.task_id,
      'location_id', new.id,
      'sender_id', new.user_id,
      'sharing_status', new.sharing_status,
      'route_path', v_route_path
    )
  );

  return new;
end;
$$;

drop trigger if exists task_locations_notify_task_party on public.task_locations;
create trigger task_locations_notify_task_party
after insert or update of latitude, longitude, sharing_status on public.task_locations
for each row execute function public.notify_task_location_update();
