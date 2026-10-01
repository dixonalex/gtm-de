<script>
	import { money } from "./format.js";

	export let rows = [];

	function points(values) {
		if (!values || values.length < 2) return "";
		const min = Math.min(...values);
		const max = Math.max(...values);
		const span = max - min || 1;
		return values
			.map((value, i) => {
				const x = (i / (values.length - 1)) * 96;
				const y = 22 - ((value - min) / span) * 18;
				return `${x.toFixed(1)},${y.toFixed(1)}`;
			})
			.join(" ");
	}

	function end(values) {
		if (!values || !values.length) return { x: 0, y: 12 };
		const min = Math.min(...values);
		const max = Math.max(...values);
		const span = max - min || 1;
		const last = values[values.length - 1];
		return { x: 96, y: 22 - ((last - min) / span) * 18 };
	}
</script>

<table>
	<thead>
		<tr>
			<th>Account</th>
			<th>Trend</th>
			<th class="num">Latest</th>
		</tr>
	</thead>
	<tbody>
		{#each rows as row}
			<tr>
				<td>
					<div class="name">{row.name}</div>
					{#if row.id}<div class="id">{row.id}</div>{/if}
				</td>
				<td>
					<svg viewBox="0 0 100 28" width="100" height="28" aria-hidden="true">
						<polyline fill="none" stroke="#9AA1A8" stroke-width="1.5" points={points(row.values)} />
						<circle
							cx={end(row.values).x}
							cy={end(row.values).y}
							r="2.5"
							fill={row.verdict === "bad" ? "#B23A32" : "#9AA1A8"}
						/>
					</svg>
				</td>
				<td class="num latest">{row.display || money(row.values[row.values.length - 1])}</td>
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
		padding: 10px 12px 10px 0;
		vertical-align: middle;
	}
	.name {
		color: var(--color-ink);
	}
	.id {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--color-context);
	}
	.latest {
		text-align: right;
		font-variant-numeric: tabular-nums;
	}
	th.num {
		text-align: right;
	}
</style>
