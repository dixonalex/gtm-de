<script>
	import { dayLabel, money } from "./format.js";

	export let rows = [];

	function ordinal(value) {
		const n = Math.round(Number(value) || 0);
		const mod = n % 100;
		const suffix = ["th", "st", "nd", "rd"];
		return `${n}${suffix[(mod - 20) % 10] || suffix[mod] || suffix[0]}`;
	}
</script>

<table>
	<thead>
		<tr>
			<th>Opportunity</th>
			<th>Segment</th>
			<th>Close date moved</th>
			<th>Slips</th>
			<th class="num">Amount</th>
			<th>Rep</th>
			<th class="right">Action</th>
		</tr>
	</thead>
	<tbody>
		{#each rows as row}
			<tr>
				<td>
					<div>{row.account_name}</div>
					<div class="id">{row.opportunity_id}</div>
				</td>
				<td>{row.segment}</td>
				<td class="num">{dayLabel(row.previous_close_date)} → {dayLabel(row.close_date)}</td>
				<td class:late={Number(row.slip_count) >= 3}>{ordinal(row.slip_count)}</td>
				<td class="num">{money(row.amount_usd)}</td>
				<td>{row.owner_name}</td>
				<td class="right"><a href="#slips">Update forecast →</a></td>
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
	.num {
		text-align: right;
		font-variant-numeric: tabular-nums;
	}
	th.num,
	.right {
		text-align: right;
	}
	.id {
		font-size: 12px;
		color: var(--color-context);
	}
	.late {
		color: var(--color-warning);
	}
	a {
		color: var(--color-focus);
		text-decoration: none;
		font-weight: 500;
	}
</style>
