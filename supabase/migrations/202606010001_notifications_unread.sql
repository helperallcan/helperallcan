create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  token text not null,
  device_id text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, token)
);

create trigger push_tokens_set_updated_at before update on public.push_tokens
for each row execute function public.set_updated_at();

alter table public.push_tokens enable row level security;

create policy "Users can manage own push tokens"
on public.push_tokens for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Admins can manage push tokens"
on public.push_tokens for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists push_tokens_user_active_idx
on public.push_tokens(user_id, is_active);

create index if not exists messages_unread_idx
on public.messages(conversation_id, read_at)
where read_at is null;

create or replace function public.notify_task_offer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_helper_name text;
begin
  select * into v_task
  from public.tasks
  where id = new.task_id;

  if not found or v_task.creator_id = new.helper_id then
    return new;
  end if;

  select display_name into v_helper_name
  from public.profiles
  where id = new.helper_id;

  insert into public.notifications (user_id, notification_type, title, body, data)
  values (
    v_task.creator_id,
    'offer',
    '收到新的帮手报价',
    coalesce(v_helper_name, '一位帮手') || '给你的任务提交了报价，请查看后选择合适的帮手。',
    jsonb_build_object(
      'task_id', new.task_id,
      'offer_id', new.id,
      'helper_id', new.helper_id
    )
  );

  return new;
end;
$$;

drop trigger if exists task_offers_notify_task_owner on public.task_offers;
create trigger task_offers_notify_task_owner
after insert on public.task_offers
for each row execute function public.notify_task_offer();

create or replace function public.notify_new_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations%rowtype;
  v_recipient_id uuid;
  v_sender_name text;
  v_preview text;
begin
  if new.message_type = 'system' then
    return new;
  end if;

  select * into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found or v_conversation.status <> 'open' then
    return new;
  end if;

  if new.sender_id = v_conversation.requester_id then
    v_recipient_id := v_conversation.helper_id;
  elsif new.sender_id = v_conversation.helper_id then
    v_recipient_id := v_conversation.requester_id;
  else
    return new;
  end if;

  select display_name into v_sender_name
  from public.profiles
  where id = new.sender_id;

  v_preview := nullif(trim(coalesce(new.body, '')), '');

  insert into public.notifications (user_id, notification_type, title, body, data)
  values (
    v_recipient_id,
    'chat',
    '收到新的聊天消息',
    coalesce(v_sender_name, '对方') || '：' || coalesce(left(v_preview, 80), '发来一条消息'),
    jsonb_build_object(
      'task_id', v_conversation.task_id,
      'conversation_id', new.conversation_id,
      'message_id', new.id,
      'sender_id', new.sender_id
    )
  );

  return new;
end;
$$;

drop trigger if exists messages_notify_recipient on public.messages;
create trigger messages_notify_recipient
after insert on public.messages
for each row execute function public.notify_new_chat_message();

create or replace function public.unread_notification_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where user_id = auth.uid()
    and read_at is null
$$;

create or replace function public.unread_chat_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.messages m
  join public.conversations c on c.id = m.conversation_id
  where m.read_at is null
    and m.sender_id <> auth.uid()
    and (c.requester_id = auth.uid() or c.helper_id = auth.uid())
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if not exists (
    select 1
    from public.conversations c
    where c.id = p_conversation_id
      and (c.requester_id = auth.uid() or c.helper_id = auth.uid() or public.is_admin())
  ) then
    raise exception 'Conversation not found or not accessible.';
  end if;

  update public.messages
  set read_at = now()
  where conversation_id = p_conversation_id
    and sender_id <> auth.uid()
    and read_at is null;

  get diagnostics v_count = row_count;

  update public.notifications
  set read_at = coalesce(read_at, now())
  where user_id = auth.uid()
    and read_at is null
    and data->>'conversation_id' = p_conversation_id::text;

  return v_count;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.notifications
  set read_at = now()
  where user_id = auth.uid()
    and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.unread_notification_count() to authenticated;
grant execute on function public.unread_chat_count() to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
