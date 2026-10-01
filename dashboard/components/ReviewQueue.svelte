<script>
	import { dayLabel, money } from "./format.js";

	export let rows = [];

	function meta(account) {
		return [account.domain, account.country, account.id].filter(Boolean).join(" · ");
	}
</script>

<div class="queue">
	{#each rows as row}
		<article class:decided={row.decision && row.decision !== "pending"}>
			<div class="pair">
				<div>
					<div class="name">{row.left.name}</div>
					<div class="meta">{meta(row.left)}</div>
				</div>
				<div class="vs">/</div>
				<div>
					<div class="name">{row.right.name}</div>
					<div class="meta">{meta(row.right)}</div>
				</div>
			</div>
			<div class="signals">
				{#if row.forSignals}<p><span>For</span> {row.forSignals}</p>{/if}
				{#if row.againstSignals}<p><span>Against</span> {row.againstSignals}</p>{/if}
			</div>
			<div class="stake num">{money(row.arr)} at stake</div>
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
	article {
		display: grid;
		grid-template-columns: minmax(0, 1.4fr) minmax(0, 1.2fr) 140px 180px;
		gap: 16px;
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
	.pair {
		display: grid;
		grid-template-columns: 1fr auto 1fr;
		gap: 8px;
	}
	.vs {
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
		font-size: 11px;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		margin-right: 6px;
	}
	.stake {
		font-variant-numeric: tabular-nums;
	}
	.decision {
		text-align: right;
	}
	.who {
		margin: 0 0 4px;
	}
	button {
		background: none;
		border: 0;
		padding: 0;
		color: var(--color-focus);
		font: inherit;
		cursor: pointer;
	}
</style>
