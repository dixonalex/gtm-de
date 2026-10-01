<script>
	import { dayLabel, money } from "./format.js";

	export let rows = [];

	function meta(account) {
		return [account.domain, account.country, account.id].filter(Boolean).join(" · ");
	}
</script>

<div class="queue">
	<div class="head">
		<span>Account A</span>
		<span>Account B</span>
		<span>Signals</span>
		<span class="right">ARR at stake</span>
		<span class="right">Decision</span>
	</div>
	{#each rows as row}
		<article class:decided={row.decision && row.decision !== "pending"}>
			<div>
				<div class="name">{row.left.name}</div>
				<div class="meta">{meta(row.left)}</div>
			</div>
			<div>
				<div class="name">{row.right.name}</div>
				<div class="meta">{meta(row.right)}</div>
			</div>
			<div class="signals">
				{#if row.forSignals}<p><span>For</span> {row.forSignals}</p>{/if}
				{#if row.againstSignals}<p><span>Against</span> {row.againstSignals}</p>{/if}
			</div>
			<div class="stake num">{money(row.arr)}</div>
			<div class="decision">
				{#if row.decision && row.decision !== "pending"}
					<p class="who">{row.decision} · {row.who} · {dayLabel(row.when)}</p>
					<button type="button">Undo</button>
				{:else}
					<p>{row.decisionLabel || "Undecided"}</p>
				{/if}
			</div>
		</article>
	{/each}
</div>

<style>
	.queue {
		border-top: 1px solid var(--color-ink);
	}
	.head,
	article {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(0, 1.2fr) 120px 160px;
		gap: 16px;
	}
	.head {
		padding: 0 0 8px;
		border-bottom: 1px solid var(--color-ink);
		font-size: 12px;
		font-weight: 500;
		color: var(--color-ink-muted);
	}
	article {
		padding: 14px 0;
		border-bottom: 1px solid var(--color-rule);
		font-size: 14px;
	}
	article.decided {
		color: var(--color-context);
	}
	article.decided .name,
	article.decided .stake {
		color: var(--color-context);
	}
	.name {
		color: var(--color-ink);
	}
	.meta {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--color-context);
		margin-top: 2px;
	}
	.signals p {
		margin: 0 0 4px;
		color: var(--color-ink-muted);
	}
	.signals span {
		font-weight: 500;
		margin-right: 6px;
	}
	.stake {
		font-variant-numeric: tabular-nums;
		text-align: right;
	}
	.decision {
		text-align: right;
	}
	.who {
		margin: 0 0 4px;
	}
	.right {
		text-align: right;
	}
	button {
		background: none;
		border: 0;
		padding: 0;
		color: var(--color-focus);
		font: inherit;
		font-weight: 500;
		cursor: pointer;
		text-decoration: none;
	}
</style>
