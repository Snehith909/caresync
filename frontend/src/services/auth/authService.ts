import { requireSupabaseClient } from "../api/client";

export async function signIn(email: string, password: string) {
  const { error } = await requireSupabaseClient().auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
}

export async function signOut() {
  const { error } = await requireSupabaseClient().auth.signOut();
  if (error) throw new Error(error.message);
}

export async function requestPasswordReset(email: string) {
  const { error } = await requireSupabaseClient().auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin,
  });
  if (error) throw new Error(error.message);
}

export async function updateRecoveredPassword(password: string) {
  const { error } = await requireSupabaseClient().auth.updateUser({ password });
  if (error) throw new Error(error.message);
}
