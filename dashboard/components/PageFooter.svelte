<script>
	export let footnotes = [];
	export let definitions = [];
	export let models = [];
</script>

<footer>
	{#if footnotes.length}
		<ol>
			{#each footnotes as note}
				<li id="fn-{note.n}"><span class="n">{note.n}</span> {note.text}</li>
			{/each}
		</ol>
	{/if}
	{#if definitions.length}
		<p class="defs" id="definitions">
			<span>Definitions</span>
			{#each definitions as item, i}
				{#if i > 0}<span class="dot">·</span>{/if}
				<a href={item.href || "#"}>{item.label}</a>
			{/each}
		</p>
	{/if}
	{#if models.length}
		<p class="models">{models.join("  ")}</p>
	{/if}
</footer>

<style>
	footer {
		margin-top: 36px;
		padding-top: 16px;
		border-top: 1px solid var(--color-rule);
	}
	ol {
		list-style: none;
		margin: 0 0 16px;
		padding: 0;
	}
	li {
		font-size: 13px;
		color: var(--color-ink-muted);
		margin-bottom: 6px;
	}
	.n {
		color: var(--color-warning);
		font-weight: 600;
		margin-right: 6px;
	}
	.defs {
		margin: 0 0 8px;
		font-size: 12px;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--color-ink-muted);
	}
	.defs a {
		color: var(--color-focus);
		text-decoration: none;
		letter-spacing: 0.08em;
	}
	.dot {
		margin: 0 8px;
	}
	.models {
		margin: 0;
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--color-context);
	}
</style>
