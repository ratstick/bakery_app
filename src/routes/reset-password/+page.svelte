<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';

  let password = $state('');
  let confirmPassword = $state('');
  let errorMessage = $state('');
  let successMessage = $state('');
  let saving = $state(false);
  let ready = $state(false); // true once Supabase confirms a valid recovery session

  onMount(() => {
    // When the recovery link is clicked, Supabase's client automatically
    // parses the token from the URL and fires this event with a valid
    // temporary session — that's what lets us safely show the form.
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        ready = true;
      }
    });

    // Also check immediately in case the event already fired before we
    // started listening (can happen depending on load timing).
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) ready = true;
    });

    return () => listener.subscription.unsubscribe();
  });

  async function handleSubmit() {
    errorMessage = '';

    if (password.length < 8) {
      errorMessage = 'Password must be at least 8 characters.';
      return;
    }
    if (password !== confirmPassword) {
      errorMessage = 'Passwords don\'t match.';
      return;
    }

    saving = true;
    const { error } = await supabase.auth.updateUser({ password });
    saving = false;

    if (error) {
      errorMessage = error.message;
      return;
    }

    successMessage = 'Password updated! Redirecting...';
    setTimeout(() => goto('/'), 1500);
  }
</script>

<h1>Set Your Password</h1>

{#if !ready}
  <p>Verifying your link...</p>
{:else if successMessage}
  <p>{successMessage}</p>
{:else}
  <form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
    <label>
      New Password
      <input type="password" bind:value={password} required minlength="8" />
    </label>
    <label>
      Confirm Password
      <input type="password" bind:value={confirmPassword} required />
    </label>

    {#if errorMessage}<p class="error">{errorMessage}</p>{/if}

    <button type="submit" disabled={saving}>
      {saving ? 'Saving...' : 'Set Password'}
    </button>
  </form>
{/if}