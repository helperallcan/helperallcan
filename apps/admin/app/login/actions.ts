'use server';

import { redirect } from 'next/navigation';

import { getAuthLoginErrorMessage } from '@/lib/auth-errors';
import { createServerSupabaseClient } from '@/lib/supabase/server';

export async function loginAction(_prevState: { error?: string }, formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const supabase = await createServerSupabaseClient();

  try {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return { error: getAuthLoginErrorMessage(error) };
  } catch (error) {
    return { error: getAuthLoginErrorMessage(error) };
  }

  redirect('/dashboard');
}

export async function logoutAction() {
  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
  redirect('/login');
}
