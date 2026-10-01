<script>
	import { dayLabel } from "./format.js";
	import StatusChip from "./StatusChip.svelte";

	export let eyebrow = "";
	export let title = "";
	export let sources = [];
	export let asOf = "";
	export let note = "";
	export let exportRows = [];

	let copied = false;

	async function copyLink() {
		const url = window.location.href;
		try {
			await navigator.clipboard.writeText(url);
		} catch {
			const input = document.createElement("textarea");
			input.value = url;
			document.body.appendChild(input);
			input.select();
			document.execCommand("copy");
			input.remove();
		}
		copied = true;
	}

	function exportCsv() {
		const rows = exportRows || [];
		if (!rows.length) return;
		const keys = Object.keys(rows[0]);
		const lines = [keys.join(",")].concat(
			rows.map((row) => keys.map((key) => JSON.stringify(row[key] ?? "")).join(",")),
		);
		const blob = new Blob([lines.join("\n")], { type: "text/csv" });
		const url = URL.createObjectURL(blob);
		const link = document.createElement("a");
		link.href = url;
		link.download = "view.csv";
		link.click();
		URL.revokeObjectURL(url);
	}

	$: asOfLabel = /^\d{4}-\d{2}-\d{2}/.test(String(asOf)) ? dayLabel(asOf) : asOf;
</script>

<header class="header">
	<div class="titles">
		{#if eyebrow}<p class="eyebrow">{eyebrow}</p>{/if}
		<div class="title-row">
			<h1>{title}<slot name="after-title" /></h1>
			<slot name="controls" />
		</div>
	</div>
	<aside>
		<div class="sources">
			{#each sources as source}
				<StatusChip status={source.status} measured={source.measured} threshold={source.threshold} />
			{/each}
		</div>
		{#if asOfLabel}<p class="asof">Data as of {asOfLabel}</p>{/if}
		{#if note}<p class="note">{note}</p>{/if}
		<p class="links">
			<button type="button" on:click={copyLink}>{copied ? "Link copied" : "Copy link to this view"}</button>
			<button type="button" on:click={exportCsv}>Export CSV</button>
		</p>
	</aside>
</header>

<style>
	.header {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(240px, 320px);
		gap: 32px;
		align-items: start;
		padding-bottom: 20px;
		border-bottom: 1px solid var(--color-rule);
		margin-bottom: 28px;
	}
	.eyebrow {
		margin: 0 0 8px;
		font-size: 12px;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--color-ink-muted);
	}
	.title-row {
		display: flex;
		align-items: baseline;
		gap: 16px;
		flex-wrap: wrap;
	}
	h1 {
		margin: 0;
		font-family: var(--font-display);
		font-size: 40px;
		line-height: 48px;
		font-weight: 500;
		letter-spacing: -0.01em;
		color: var(--color-ink);
	}
	aside {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 8px;
		text-align: right;
	}
	.sources {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 6px;
	}
	.asof,
	.note,
	.links {
		margin: 0;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
	.links {
		display: flex;
		gap: 12px;
	}
	button {
		background: none;
		border: 0;
		padding: 0;
		font: inherit;
		color: var(--color-focus);
		cursor: pointer;
		text-decoration: underline;
		text-underline-offset: 2px;
	}
	@media (max-width: 800px) {
		.header {
			grid-template-columns: 1fr;
		}
		aside {
			align-items: flex-start;
			text-align: left;
		}
		.sources {
			align-items: flex-start;
		}
	}
</style>
