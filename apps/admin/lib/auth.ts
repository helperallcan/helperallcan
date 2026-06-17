import { redirect } from 'next/navigation';

import { adminSupabase } from './supabase/admin';
import { createServerSupabaseClient } from './supabase/server';

export type AdminProfile = {
  id: string;
  display_name: string;
  role: string;
};

export async function requireAdmin(): Promise<AdminProfile> {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  let profile: AdminProfile | null = null;
  let profileError: { message: string } | null = null;

  try {
    const result = await adminSupabase
      .from('profiles')
      .select('id, display_name, role')
      .eq('id', user.id)
      .single();

    profile = result.data;
    profileError = result.error;
  } catch {
    redirect('/login?error=config');
  }

  if (profileError) {
    redirect('/login?error=config');
  }

  if (!profile || profile.role !== 'admin') {
    redirect('/login?error=admin');
  }

  return profile;
}
