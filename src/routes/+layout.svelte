<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';

  let { children } = $props();
  let checked = $state(false);
  let session = $state(null);

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    session = data.session;

    const onLoginPage = $page.url.pathname === '/login';

    if (!session && !onLoginPage) {
      goto('/login');
    } else if (session && onLoginPage) {
      goto('/');
    }

    checked = true;

    supabase.auth.onAuthStateChange((event, newSession) => {
      session = newSession;
      if (!newSession && $page.url.pathname !== '/login') {
        goto('/login');
      }
    });
  });

  async function handleLogout() {
    await supabase.auth.signOut();
    goto('/login');
  }
</script>

{#if checked}
  {#if session}
    <nav>
      <span>Bakery App</span>
      <button onclick={handleLogout}>Log Out</button>
    </nav>
  {/if}

  {@render children()}
{/if}