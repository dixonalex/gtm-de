<script>
	export let period = "2026-08";
	export let compare = "plan";
	export let periods = [];
	export let compares = [];
	export let filters = [];
	export let context = "";

	let localFilters = [];
	$: localFilters = filters.map((filter) => ({ ...filter }));

	function clear(index) {
		localFilters[index].active = false;
		localFilters[index].value = "All";
		localFilters = localFilters;
	}
</script>

<div class="bar">
	<label class="period">
		<span class="sr">Period</span>
		<select bind:value={period}>
			{#each periods as item}
				<option value={item.value}>{item.label}</option>
			{/each}
		</select>
	</label>
	<span class="vs">vs</span>
	<label class="compare">
		<span class="sr">Compare</span>
		<select bind:value={compare}>
			{#each compares as item}
				<option value={item.value}>{item.label}</option>
			{/each}
		</select>
	</label>
	<span class="divider"></span>
	{#each localFilters as filter, index}
		<label class="filter" class:active={filter.active}>
			<span class="field">{filter.label}</span>
			<select
				bind:value={filter.value}
				on:change={() => {
					filter.active = filter.value !== "All";
					localFilters = localFilters;
				}}
			>
				{#each filter.options as item}
					<option value={item}>{item}</option>
				{/each}
			</select>
			{#if filter.active}
				<button type="button" aria-label="Clear {filter.label}" on:click={() => clear(index)}>×</button>
			{/if}
		</label>
	{/each}
</div>
{#if context}
	<p class="context">{context}</p>
{/if}

<style>
	.bar {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-wrap: wrap;
		margin-bottom: 8px;
	}
	label {
		display: inline-flex;
		align-items: center;
		border: 1px solid var(--color-rule);
		background: var(--color-ground);
		height: 32px;
		padding: 0 8px;
	}
	label.period {
		border-color: var(--color-ink);
	}
	label.period select {
		font-size: 15px;
		font-weight: 500;
	}
	.field {
		margin-right: 6px;
		font-size: 14px;
		color: var(--color-ink);
	}
	label.active {
		border-color: var(--color-focus);
		background: var(--color-seq-1);
	}
	label.active select {
		color: var(--color-focus);
	}
	select {
		border: 0;
		background: transparent;
		font-family: var(--font-sans);
		font-size: 14px;
		color: var(--color-ink);
		padding-right: 4px;
	}
	button {
		border: 0;
		background: transparent;
		color: var(--color-focus);
		font-size: 16px;
		line-height: 1;
		cursor: pointer;
		padding: 0 2px;
	}
	.vs {
		color: var(--color-ink-muted);
		font-size: 13px;
	}
	.divider {
		width: 1px;
		height: 20px;
		background: var(--color-rule);
		margin: 0 4px;
	}
	.context {
		margin: 0 0 16px;
		padding: 8px 12px;
		background: var(--color-wash);
		border-left: 3px solid var(--color-focus);
		color: var(--color-ink);
		font-size: 13px;
	}
	.sr {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip: rect(0 0 0 0);
	}
</style>
