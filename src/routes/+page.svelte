<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';

  let result = $state(null);
  let error = $state(null);

  onMount(async () => {
    const { data, error: err } = await supabase
      .from('ingredients')
      .select('*');

    result = data;
    error = err;
  });
</script>

<h1>Supabase connection test</h1>

<h2>Data:</h2>
<pre>{JSON.stringify(result, null, 2)}</pre>

<h2>Error:</h2>
<pre>{JSON.stringify(error, null, 2)}</pre>