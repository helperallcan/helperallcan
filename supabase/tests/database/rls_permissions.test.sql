begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(36);

create temporary table test_flags (
  name text primary key,
  passed boolean not null default false,
  detail text
) on commit drop;

create temporary table test_ids (
  name text primary key,
  id uuid not null
) on commit drop;

grant all on table test_flags to authenticated;
grant all on table test_ids to authenticated;

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner@example.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Owner"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'helper@example.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Helper"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'outsider@example.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Outsider"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@example.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

set local "request.jwt.claim.role" = 'service_role';
update public.profiles
set
  display_name = case id
    when '00000000-0000-0000-0000-000000000101' then 'Owner'
    when '00000000-0000-0000-0000-000000000102' then 'Helper'
    when '00000000-0000-0000-0000-000000000103' then 'Outsider'
    when '00000000-0000-0000-0000-000000000104' then 'Admin'
    else display_name
  end,
  role = case id
    when '00000000-0000-0000-0000-000000000104' then 'admin'::public.app_role
    else 'user'::public.app_role
  end,
  is_blocked = false,
  verification_status = 'none'::public.verification_status
where id in (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000103',
  '00000000-0000-0000-0000-000000000104'
);
set local "request.jwt.claim.role" = '';

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
update public.profiles
set display_name = 'Owner Updated'
where id = '00000000-0000-0000-0000-000000000101';
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-000000000101'),
  'Owner Updated',
  'users can update their own profile'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
update public.profiles
set display_name = 'Helper Hacked'
where id = '00000000-0000-0000-0000-000000000102';
reset role;
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-000000000102'),
  'Helper',
  'users cannot update another profile'
);

insert into test_flags (name) values ('owner_cannot_promote_self');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  update public.profiles
  set role = 'admin'::public.app_role
  where id = '00000000-0000-0000-0000-000000000101';

  update test_flags
  set passed = false,
      detail = 'promotion unexpectedly succeeded'
  where name = 'owner_cannot_promote_self';
exception
  when others then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'owner_cannot_promote_self';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'owner_cannot_promote_self'),
  'non-admin users cannot promote themselves to admin'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000104';
set local "request.jwt.claim.role" = 'authenticated';
update public.profiles
set is_blocked = true
where id = '00000000-0000-0000-0000-000000000103';
select ok(
  (select is_blocked from public.profiles where id = '00000000-0000-0000-0000-000000000103'),
  'admins can block users'
);
update public.profiles
set is_blocked = false
where id = '00000000-0000-0000-0000-000000000103';
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.tasks (
  id,
  creator_id,
  title,
  description,
  task_type,
  location_text,
  budget_max,
  is_urgent
)
values (
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000101',
  'Need a helper',
  'Please help move one desk.',
  'help'::public.task_type,
  'Singapore',
  80,
  true
);
select is(
  (select count(*)::integer from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'active users can create their own tasks'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
select is(
  (select count(*)::integer from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'helpers can view open tasks'
);
update public.tasks
set title = 'Helper hacked title'
where id = '00000000-0000-0000-0000-000000000201';
reset role;
select is(
  (select title from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  'Need a helper',
  'helpers cannot update tasks they do not own'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.helper_profiles (
  id,
  user_id,
  headline,
  bio,
  skills,
  service_areas
)
values (
  '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-000000000102',
  'Reliable helper',
  'Local helper for errands and moving.',
  array['moving', 'errands'],
  array['Singapore']
);
select is(
  (select count(*)::integer from public.helper_profiles where user_id = '00000000-0000-0000-0000-000000000102'),
  1,
  'users can create their own helper profile'
);

select is(
  public.request_helper_verification(),
  'pending'::public.verification_status,
  'helpers can request verification for their own helper profile'
);

select is(
  (select verification_status from public.helper_profiles where user_id = '00000000-0000-0000-0000-000000000102'),
  'pending'::public.verification_status,
  'helper verification requests are saved as pending'
);

insert into public.task_offers (
  id,
  task_id,
  helper_id,
  amount,
  message
)
values (
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000102',
  70,
  'I can do this today.'
);
select is(
  (select count(*)::integer from public.task_offers where id = '00000000-0000-0000-0000-000000000401'),
  1,
  'helpers can quote open tasks'
);
reset role;

select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  'offered'::public.task_status,
  'task status changes to offered after first quote'
);

insert into test_flags (name) values ('helper_cannot_duplicate_offer');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  insert into public.task_offers (
    task_id,
    helper_id,
    amount,
    message
  )
  values (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000102',
    75,
    'Duplicate quote.'
  );

  update test_flags
  set passed = false,
      detail = 'duplicate offer unexpectedly succeeded'
  where name = 'helper_cannot_duplicate_offer';
exception
  when unique_violation then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'helper_cannot_duplicate_offer';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'helper_cannot_duplicate_offer'),
  'helpers cannot quote the same task twice'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.tasks (
  id,
  creator_id,
  title,
  description,
  task_type,
  location_text
)
values (
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000101',
  'Withdraw test task',
  'Task for checking offer withdrawal.',
  'help'::public.task_type,
  'Singapore'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.task_offers (
  id,
  task_id,
  helper_id,
  amount,
  message
)
values (
  '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000102',
  60,
  'I can withdraw this quote.'
);
select is(
  public.withdraw_task_offer('00000000-0000-0000-0000-000000000402'),
  'withdrawn'::public.offer_status,
  'helpers can withdraw pending offers through the RPC'
);
reset role;
select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-000000000202'),
  'open'::public.task_status,
  'tasks return to open when the last pending offer is withdrawn'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.tasks (
  id,
  creator_id,
  title,
  description,
  task_type,
  location_text
)
values (
  '00000000-0000-0000-0000-000000000203',
  '00000000-0000-0000-0000-000000000101',
  'Cancel test task',
  'Task for checking task cancellation.',
  'help'::public.task_type,
  'Singapore'
);
select is(
  public.cancel_task('00000000-0000-0000-0000-000000000203', 'No longer needed.'),
  'cancelled'::public.task_status,
  'task owners can cancel active tasks through the RPC'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.tasks (
  id,
  creator_id,
  title,
  description,
  task_type,
  location_text
)
values (
  '00000000-0000-0000-0000-000000000204',
  '00000000-0000-0000-0000-000000000101',
  'Reopen test task',
  'Task for checking helper reselection.',
  'help'::public.task_type,
  'Singapore'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.task_offers (
  id,
  task_id,
  helper_id,
  amount,
  message
)
values (
  '00000000-0000-0000-0000-000000000404',
  '00000000-0000-0000-0000-000000000204',
  '00000000-0000-0000-0000-000000000102',
  90,
  'I can be selected first.'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.accept_task_offer('00000000-0000-0000-0000-000000000404');
end
$$;
select is(
  public.reopen_task_for_offers('00000000-0000-0000-0000-000000000204', 'Need another helper.'),
  'open'::public.task_status,
  'task owners can reopen assigned tasks for new offers'
);
reset role;
select ok(
  (select assigned_helper_id is null from public.tasks where id = '00000000-0000-0000-0000-000000000204'),
  'reopened tasks clear the selected helper'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
select is(
  (select count(*)::integer from public.task_offers where id = '00000000-0000-0000-0000-000000000401'),
  1,
  'task owners can view offers on their task'
);
reset role;

insert into test_flags (name) values ('helper_cannot_accept_offer_directly');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  update public.task_offers
  set status = 'accepted'::public.offer_status
  where id = '00000000-0000-0000-0000-000000000401';

  update test_flags
  set passed = false,
      detail = 'direct accept unexpectedly succeeded'
  where name = 'helper_cannot_accept_offer_directly';
exception
  when others then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'helper_cannot_accept_offer_directly';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'helper_cannot_accept_offer_directly'),
  'helpers cannot directly mark their offer as accepted'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.accept_task_offer('00000000-0000-0000-0000-000000000401');
end
$$;
reset role;

select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  'assigned'::public.task_status,
  'task owners can accept an offer through the RPC'
);
select is(
  (select status from public.task_offers where id = '00000000-0000-0000-0000-000000000401'),
  'accepted'::public.offer_status,
  'accepted offer is marked accepted by the RPC'
);
select is(
  (select count(*)::integer from public.conversations where task_id = '00000000-0000-0000-0000-000000000201'),
  1,
  'accepting an offer creates the task conversation'
);

insert into test_ids (name, id)
select 'accepted_conversation', id
from public.conversations
where task_id = '00000000-0000-0000-0000-000000000201'
limit 1;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000103';
set local "request.jwt.claim.role" = 'authenticated';
select is(
  (select count(*)::integer from public.conversations where task_id = '00000000-0000-0000-0000-000000000201'),
  0,
  'outsiders cannot read task conversations'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.messages (
  conversation_id,
  sender_id,
  body
)
values (
  (select id from test_ids where name = 'accepted_conversation'),
  '00000000-0000-0000-0000-000000000102',
  'I am on the way.'
);
select is(
  (select count(*)::integer from public.messages where conversation_id = (select id from test_ids where name = 'accepted_conversation')),
  1,
  'conversation participants can send messages'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000103';
set local "request.jwt.claim.role" = 'authenticated';
select is(
  (select count(*)::integer from public.messages where conversation_id = (select id from test_ids where name = 'accepted_conversation')),
  0,
  'outsiders cannot read conversation messages'
);
reset role;

insert into test_flags (name) values ('outsider_cannot_send_message');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000103';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  insert into public.messages (
    conversation_id,
    sender_id,
    body
  )
  values (
    (select id from test_ids where name = 'accepted_conversation'),
    '00000000-0000-0000-0000-000000000103',
    'Let me in.'
  );

  update test_flags
  set passed = false,
      detail = 'outsider message unexpectedly succeeded'
  where name = 'outsider_cannot_send_message';
exception
  when others then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'outsider_cannot_send_message';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'outsider_cannot_send_message'),
  'outsiders cannot send messages to unrelated conversations'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.reports (
  id,
  reporter_id,
  target_type,
  target_id,
  reason,
  details
)
values (
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000101',
  'task',
  '00000000-0000-0000-0000-000000000201',
  'spam',
  'Suspicious offer.'
);
select is(
  (select count(*)::integer from public.reports where id = '00000000-0000-0000-0000-000000000501'),
  1,
  'users can create reports'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
update public.reports
set status = 'resolved'::public.report_status
where id = '00000000-0000-0000-0000-000000000501';
reset role;
select is(
  (select status from public.reports where id = '00000000-0000-0000-0000-000000000501'),
  'open'::public.report_status,
  'non-admin users cannot resolve reports'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000104';
set local "request.jwt.claim.role" = 'authenticated';
update public.reports
set status = 'resolved'::public.report_status
where id = '00000000-0000-0000-0000-000000000501';
select is(
  (select status from public.reports where id = '00000000-0000-0000-0000-000000000501'),
  'resolved'::public.report_status,
  'admins can resolve reports'
);
reset role;

insert into test_flags (name) values ('user_cannot_write_admin_log');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.write_admin_log('update', 'profiles', '00000000-0000-0000-0000-000000000102'::uuid, '{"blocked":true}'::jsonb);

  update test_flags
  set passed = false,
      detail = 'admin log unexpectedly succeeded'
  where name = 'user_cannot_write_admin_log';
exception
  when others then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'user_cannot_write_admin_log';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'user_cannot_write_admin_log'),
  'non-admin users cannot write admin logs'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000104';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.write_admin_log('resolve', 'reports', '00000000-0000-0000-0000-000000000501'::uuid, '{"status":"resolved"}'::jsonb);
end
$$;
select is(
  (select count(*)::integer from public.admin_logs where admin_id = '00000000-0000-0000-0000-000000000104'),
  1,
  'admins can write admin logs through the RPC'
);
reset role;

insert into test_flags (name) values ('outsider_cannot_submit_completion_proof');
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000103';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.submit_completion_proof(
    '00000000-0000-0000-0000-000000000201',
    'I finished it.',
    'task-images/proof.jpg'
  );

  update test_flags
  set passed = false,
      detail = 'completion proof unexpectedly succeeded'
  where name = 'outsider_cannot_submit_completion_proof';
exception
  when others then
    update test_flags
    set passed = true,
        detail = sqlerrm
    where name = 'outsider_cannot_submit_completion_proof';
end
$$;
reset role;
select ok(
  (select passed from test_flags where name = 'outsider_cannot_submit_completion_proof'),
  'only the assigned helper can submit completion proof'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.submit_completion_proof(
    '00000000-0000-0000-0000-000000000201',
    'Desk moved and cleaned.',
    'task-images/proof.jpg'
  );
end
$$;
reset role;
select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  'in_progress'::public.task_status,
  'assigned helpers can submit completion proof'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';
set local "request.jwt.claim.role" = 'authenticated';
do $$
begin
  perform public.confirm_task_completed('00000000-0000-0000-0000-000000000201');
end
$$;
reset role;
select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-000000000201'),
  'completed'::public.task_status,
  'task owners can confirm completion'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';
set local "request.jwt.claim.role" = 'authenticated';
insert into public.reviews (
  id,
  task_id,
  reviewer_id,
  reviewee_id,
  rating,
  comment
)
values (
  '00000000-0000-0000-0000-000000000601',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000101',
  5,
  'Clear request and fast confirmation.'
);
select is(
  (select count(*)::integer from public.reviews where id = '00000000-0000-0000-0000-000000000601'),
  1,
  'task parties can review each other after completion'
);
reset role;

select * from finish();

rollback;

