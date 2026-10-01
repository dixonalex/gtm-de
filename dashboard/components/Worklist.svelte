<script>
	import { money } from "./format.js";

	export let rows = [];

	function tone(age, sla) {
		const ratio = sla ? age / sla : 0;
		if (ratio > 1) return "bad";
		if (ratio >= 0.5) return "warn";
		return "ok";
	}

	function geometry(age, sla) {
		const scale = Math.max(age, sla, 1);
		return {
			fill: (age / scale) * 96,
			tick: (sla / scale) * 96,
		};
	}
</script>

<table>
	<thead>
		<tr>
			<th>Record</th>
			<th>Age vs SLA</th>
			<th class="right">Amount</th>
			<th>Owner</th>
			<th></th>
		</tr>
	</thead>
	<tbody>
		{#each rows as row}
			{@const kind = tone(row.age, row.sla)}
			{@const geo = geometry(row.age, row.sla)}
			<tr>
				<td>
					<div class="name">{row.name}</div>
					<div class="id">{row.id}</div>
					{#if row.description}<div class="desc">{row.description}</div>{/if}
				</td>
				<td>
					<div class="age">
						<div class="track">
							<div class="fill {kind}" style="width: {geo.fill}px"></div>
							<div class="tick" style="left: {geo.tick}px"></div>
						</div>
						<span class="age-text {kind} num">{Math.round(row.age)}d / {Math.round(row.sla)}d</span>
					</div>
				</td>
				<td class="right num">{money(row.amount)}</td>
				<td>{row.owner}</td>
				<td class="action">{#if row.action}<a href={row.href || "#"}>{row.action}</a>{/if}</td>
			</tr>
		{/each}
	</tbody>
</table>

<style>
	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}
	th {
		text-align: left;
		font-size: 12px;
		font-weight: 500;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--color-ink-muted);
		border-bottom: 1px solid var(--color-ink);
		padding: 0 12px 8px 0;
	}
	td {
		border-bottom: 1px solid var(--color-rule);
		padding: 12px 12px 12px 0;
		vertical-align: top;
	}
	.name {
		color: var(--color-ink);
	}
	.id {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--color-context);
		margin-top: 2px;
	}
	.desc {
		margin-top: 4px;
		color: var(--color-ink-muted);
		font-size: 13px;
	}
	.age {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.track {
		position: relative;
		width: 96px;
		height: 6px;
		background: var(--color-wash);
	}
	.fill {
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
	}
	.fill.ok {
		background: var(--color-ink-muted);
	}
	.fill.warn {
		background: var(--color-warning);
	}
	.fill.bad {
		background: var(--color-unfavorable);
	}
	.tick {
		position: absolute;
		top: -3px;
		width: 1px;
		height: 12px;
		background: var(--color-ink);
	}
	.age-text {
		font-size: 13px;
	}
	.age-text.ok {
		color: var(--color-ink-muted);
	}
	.age-text.warn {
		color: var(--color-warning);
	}
	.age-text.bad {
		color: var(--color-unfavorable);
	}
	.right {
		text-align: right;
		font-variant-numeric: tabular-nums;
	}
	.action a {
		color: var(--color-focus);
		text-decoration: none;
		white-space: nowrap;
	}
</style>
