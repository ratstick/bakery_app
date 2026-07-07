<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';
  import '../app.css';
  
  let { children } = $props();
  let checked = $state(false);
  let session = $state(null);

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    session = data.session;

const path = $page.url.pathname;
const onLoginPage = path === '/login';
const onResetPasswordPage = path === '/reset-password';

if (!session && !onLoginPage && !onResetPasswordPage) {
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
  <nav class="no-print">
    <span>Bakery App</span>
    <a href="/ingredients">Ingredients</a>
    <a href="/recipes">Recipes</a>
    <a href="/inventory">Inventory</a>
    <span class="logged-in-as">Logged in as: {session.user.email}</span>
    <button onclick={handleLogout}>Log Out</button>
  </nav>
{/if}

  {@render children()}
{/if}