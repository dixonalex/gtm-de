<script>
	export let title = "";
	export let subtitle = "";
	export let definitionHref = "#definitions";
</script>

<section class="block">
	<div class="head">
		<div>
			<h2>{title}</h2>
			{#if subtitle || definitionHref}
				<p class="sub">
					{subtitle}
					{#if definitionHref}<a href={definitionHref}>definition</a>{/if}
				</p>
			{/if}
		</div>
		<div class="toggle">
			<slot name="toggle" />
		</div>
	</div>
	<slot />
</section>

<style>
	.block {
		margin: 8px 0 28px;
	}
	.head {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 16px;
		margin-bottom: 8px;
	}
	h2 {
		margin: 0;
		font-family: var(--font-sans);
		font-size: 18px;
		font-weight: 600;
		letter-spacing: -0.01em;
		color: var(--color-ink);
	}
	.sub {
		margin: 4px 0 0;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
	.sub a {
		margin-left: 8px;
		color: var(--color-focus);
	}
	.toggle {
		flex: 0 0 auto;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
</style>
