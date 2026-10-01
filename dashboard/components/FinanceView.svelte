<script>
	import ActualVsPlanLine from "./ActualVsPlanLine.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SignedBridge from "./SignedBridge.svelte";
	import SparklineTable from "./SparklineTable.svelte";
	import StatusChip from "./StatusChip.svelte";
	import { asRows, count, dayLabel, days, localMoney, money, monthLabel, onlyLabel, percent } from "./format.js";

	export let kpi = [];
	export let currencies = [];
	export let aging = [];
	export let burn = [];
	export let orders = [];
	export let freshness = [];

	function ago(row) {
		const minutes = Number(row.age_minutes);
		if (minutes < 60) return `${Math.round(minutes)}m ago`;
		return `${Math.round(minutes / 60)}h ago`;
	}

	function tie(row) {
		if (!row || row.currency === "Total") return null;
		if (row.tie_out_status === "error") return { status: "error", measured: "JPY amount conversion" };
		if (row.tie_out_status === "warn") return { status: "warn", measured: `${percent(row.unmatched_share)} unmatched, tolerance 1%` };
		return { status: "pass" };
	}

	$: row = asRows(kpi)[0] || {};
	$: period = monthLabel(row.month_end);
	$: sliceText = onlyLabel([row.currency, row.segment]);
	$: sources = asRows(freshness)
		.slice()
		.sort((a, b) => (a.connector_id === "salesforce" ? -1 : 1))
		.map((item) => ({
			name: item.connector_id === "stripe" ? "Billing" : "Salesforce",
			ago: ago(item),
			sla: item.status === "PASS" ? "" : "24h",
			late: item.status !== "PASS",
		}));

	function stepsOf(item) {
		const steps = [
			{ label: "Bookings", value: Number(item.bookings_usd), role: "open" },
			{ label: "Renewals", value: Number(item.renewals_usd), role: "up" },
			{ label: "Usage overage", value: Number(item.overage_usd), role: "up" },
			{ label: "Booked not billed", value: -Number(item.booked_not_billed_usd), role: "down" },
			{ label: "Cancels", value: -Number(item.cancels_usd), role: "down" },
			{ label: "Billed without order", value: Number(item.billed_without_order_usd), role: "up" },
			{ label: "Billings", value: Number(item.billings_usd), role: "close" },
		];
		return steps.filter((step) => step.role === "open" || step.role === "close" || Math.abs(step.value) >= 500);
	}

	$: steps = stepsOf(row);
	$: ages = asRows(aging);
	$: latest = ages[ages.length - 1] || {};
	function series(key) {
		return ages.map((item) => Number(item[key] || 0));
	}
	$: spark = [
		{ name: "Current", values: series("current_usd"), compare: money(latest.current_vs_mar_usd, { signed: true }) },
		{ name: "1–30", values: series("bucket_1_30_usd"), compare: money(latest.bucket_1_30_vs_mar_usd, { signed: true }) },
		{ name: "31–90", values: series("bucket_31_90_usd"), compare: money(latest.bucket_31_90_vs_mar_usd, { signed: true }) },
		{ name: "Over 90", values: series("over_90_usd"), compare: money(latest.over_90_vs_mar_usd, { signed: true }), verdict: latest.alert_over_90 ? "bad" : "" },
		{ name: "Total AR", values: series("ar_usd"), compare: money(latest.ar_vs_mar_usd, { signed: true }) },
		{ name: "DSO", values: series("dso_days"), display: days(latest.dso_days), compare: latest.dso_vs_mar == null ? "" : `${Number(latest.dso_vs_mar) > 0 ? "+" : ""}${Number(latest.dso_vs_mar).toFixed(1)}d`, verdict: latest.alert_dso ? "bad" : "" },
	];
	$: burnRows = asRows(burn);
</script>

<PageHeader
	eyebrow="FINANCE · MONTH-END CLOSE"
	title="Bookings to billings"
	{sources}
	asOf={asRows(freshness)[0]?.as_of_date || ""}
	note="Close snapshot 3 Sep · no restatements since"
	exportLabel="Export for close file"
	exportRows={[row]}
>
	<div slot="controls" class="slice-controls">
		<slot name="controls" />
	</div>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Bookings" period={period} value={row.bookings_usd} plan={row.bookings_plan_usd} prior={row.prior_bookings_usd} priorLabel="Jul 2026" />
	<KpiTile label="Billings" period={period} value={row.billings_usd} prior={row.prior_billings_usd} priorLabel="Jul 2026" caveat={1} />
	<KpiTile label="Booked not billed" period="month-end" value={row.booked_not_billed_usd} prior={row.prior_booked_not_billed_usd} priorLabel="Jul 2026" context={`${count(row.bnb_orders)} orders · ${count(row.bnb_past_sla)} past invoicing SLA`} />
	<KpiTile
		label="Unmatched invoices"
		value={row.unmatched_usd}
		verdictText={`${percent(row.unmatched_share)} of billings · tolerance 1%`}
		verdictColor={Number(row.unmatched_share) > 0.01 ? "var(--color-unfavorable)" : "var(--color-ink)"}
		context={`${count(row.unmatched_invoices)} invoices · Jul: ${count(row.prior_unmatched_invoices)}`}
	/>
</div>

<ChartBlock title="Bookings to billings, {period.replace(/ \d{4}$/, '')}" subtitle={sliceText || "Company"}>
	<div slot="toggle" class="inert" aria-label="Break down by">
		<button type="button" class="on">None</button>
		<button type="button">Currency</button>
	</div>
	<SignedBridge {steps} zeroBased />
</ChartBlock>

<section class="block">
	<h2>Billings reconciliation by currency</h2>
	<table>
		<thead>
			<tr>
				<th>Currency</th>
				<th class="num">Booked</th>
				<th class="num">Billed</th>
				<th class="num">Billed (local)</th>
				<th class="num">Unmatched</th>
				<th>Tie-out</th>
			</tr>
		</thead>
		<tbody>
			{#each asRows(currencies) as item}
				{@const chip = tie(item)}
				<tr>
					<td>{item.currency}</td>
					<td class="num">{money(item.booked_usd)}</td>
					<td class="num">{money(item.billed_usd)}</td>
					<td class="num">{localMoney(item.currency, item.billed_local)}</td>
					<td class="num">{money(item.unmatched_usd)}</td>
					<td>{#if chip}<StatusChip status={chip.status} measured={chip.measured || ""} />{/if}</td>
				</tr>
			{/each}
		</tbody>
	</table>
</section>

<div class="two-up even">
	<ChartBlock title="Receivables aging by bucket" subtitle="Mar–{period.slice(0, 3)}">
		<SparklineTable rows={spark} nameHeader="Bucket" compareHeader="vs Mar" />
	</ChartBlock>
	<ChartBlock title="Usage commit burn vs straight line" subtitle={sliceText || "Annual commits active 1 Jan"}>
		<ActualVsPlanLine
			labels={burnRows.map((item) => monthLabel(item.month_end))}
			actual={burnRows.map((item) => Number(item.share_consumed))}
			plan={burnRows.map((item) => Number(item.straight_line))}
			actualName="Consumed"
			planName="Straight line"
			format={(value) => percent(value, 1)}
			axisFormat={(value) => percent(value)}
			yDomain={{ min: 0, max: 0.8, ticks: [0, 0.2, 0.4, 0.6, 0.8] }}
			pointGap
		/>
	</ChartBlock>
</div>

<section id="unbilled">
	<ChartBlock title="Booked, not billed" subtitle={sliceText || period}>
		<table>
			<thead>
				<tr>
					<th>Account</th>
					<th>Product, activated</th>
					<th>Age vs SLA</th>
					<th class="num">Amount</th>
					<th>Owner</th>
				</tr>
			</thead>
			<tbody>
				{#each asRows(orders) as item}
					<tr>
						<td>
							<div>{item.account_name}</div>
							<div class="id">{item.order_id}</div>
						</td>
						<td>{item.product_code}, {dayLabel(item.effective_date)}</td>
						<td class:bad={Number(item.age_bd) > Number(item.sla_bd)}>{item.age_bd}d / {item.sla_bd}d</td>
						<td class="num">{money(item.amount_usd)}</td>
						<td>{item.owner_name}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
</section>

<PageFooter
	footnotes={[{ n: 1, text: "Billing synced past its 24h SLA. Billings and unmatched invoices can still move." }]}
	definitions={[{ label: "Bookings" }, { label: "Billings" }, { label: "Booked not billed" }, { label: "DSO" }]}
	models={["rpt_finance_month", "rpt_finance_currency", "rpt_commit_burn", "fct_ar_aging"]}
/>

<style>
	h2 { margin: 0 0 12px; font-size: 18px; font-weight: 600; }
	.block { margin: 8px 0 28px; }
	table { width: 100%; border-collapse: collapse; font-size: 14px; }
	th {
		text-align: left;
		font-size: 12px;
		font-weight: 500;
		color: var(--color-ink-muted);
		border-bottom: 1px solid var(--color-ink);
		padding: 0 12px 8px 0;
	}
	td { border-bottom: 1px solid var(--color-rule); padding: 12px 12px 12px 0; }
	.num { text-align: right; }
	th.num { text-align: right; }
	.id { font-size: 12px; color: var(--color-context); }
	.bad { color: var(--color-unfavorable); }
</style>
