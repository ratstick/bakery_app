<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';

  let email = $state('');
  let password = $state('');
  let errorMessage = $state('');
  let loading = $state(false);

  async function handleLogin() {
    loading = true;
    errorMessage = '';

    const { error } = await supabase.auth.signInWithPassword({ email, password });

    loading = false;

    if (error) {
      errorMessage = error.message;
      return;
    }

    goto('/');
  }
</script>

<h1>Log In</h1>

<form onsubmit={(e) => { e.preventDefault(); handleLogin(); }}>
  <label>
    Email
    <input type="email" bind:value={email} required />
  </label>

  <label>
    Password
    <input type="password" bind:value={password} required />
  </label>

  {#if errorMessage}
    <p class="error">{errorMessage}</p>
  {/if}

  <button type="submit" disabled={loading}>
    {loading ? 'Logging in...' : 'Log In'}
  </button>
</form>