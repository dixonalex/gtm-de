<script>
	import CaveatMarker from "./CaveatMarker.svelte";
	import { money } from "./format.js";

	export let rows = [];

	function tone(age, sla) {
		const ratio = sla ? age / sla : 0;
		if (ratio > 1) return "bad";
		if (ratio >= 0.5) return "warn";
		return "ok";
	}

	function geometry(age, sla) {
		const ratio = sla ? age / sla : 0;
		return {
			fill: (Math.min(ratio, 1.5) / 1.5) * 96,
			tick: 64,
		};
	}

	function ageText(age) {
		if (age < 1) return "<1d";
		return `${Math.round(age)}d`;
	}
</script>

<table id="worklist">
	<thead>
		<tr>
			<th>Record</th>
			<th>Exception</th>
			<th>Age vs SLA</th>
			<th class="right">At stake</th>
			<th>Owner</th>
			<th class="right">Action</th>
		</tr>
	</thead>
	<tbody>
		{#each rows as row}
			{@const kind = tone(row.age, row.sla)}
			{@const geo = geometry(row.age, row.sla)}
			<tr>
				<td>
					<div class="name">{row.name}{#if row.caveat}<CaveatMarker n={row.caveat} />{/if}</div>
					<div class="id">{row.id}</div>
				</td>
				<td class="exception">{row.description}</td>
				<td>
					<div class="age">
						<div class="track">
							<div class="fill {kind}" style="width: {geo.fill}px"></div>
							<div class="tick" style="left: {geo.tick}px"></div>
						</div>
						<span class="age-text {kind} num">{row.ageLabel || `${ageText(row.age)} / ${Math.round(row.sla)}d`}</span>
					</div>
				</td>
				<td class="right num">{money(row.amount)}</td>
				<td>{row.owner}</td>
				<td class="action right">{#if row.action}<a href={row.href || "#worklist"}>{row.action}</a>{/if}</td>
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
	.exception {
		color: var(--color-ink-muted);
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
		flex: 0 0 96px;
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
		white-space: nowrap;
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
		font-weight: 500;
		text-decoration: none;
		white-space: nowrap;
	}
</style>
