create or replace function public.request_helper_verification()
returns public.verification_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.verification_status;
begin
  if not public.is_active_user(auth.uid()) then
    raise exception 'Only active users can request helper verification.';
  end if;

  perform set_config('app.bypass_helper_guard', 'on', true);

  update public.helper_profiles
  set verification_status = case
        when verification_status = 'approved' then verification_status
        else 'pending'::public.verification_status
      end,
      verification_note = case
        when verification_status = 'approved' then verification_note
        else null
      end
  where user_id = auth.uid()
  returning verification_status into v_status;

  if v_status is null then
    raise exception 'Create a helper profile before requesting verification.';
  end if;

  return v_status;
end;
$$;

grant execute on function public.request_helper_verification() to authenticated;
