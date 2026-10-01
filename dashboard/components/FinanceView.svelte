<script>
	import { onMount } from "svelte";
	import ActualVsPlanLine from "./ActualVsPlanLine.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SignedBridge from "./SignedBridge.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import SparklineTable from "./SparklineTable.svelte";
	import StatusChip from "./StatusChip.svelte";
	import Worklist from "./Worklist.svelte";
	import { days, isoDate, money, monthLabel, percent } from "./format.js";

	export let bookings = [];
	export let bridge = [];
	export let currency = [];
	export let aging = [];
	export let unbilled = [];
	export let burn = [];
	export let freshness = [];

	const SEGMENT_ORDER = ["Enterprise", "Mid-market", "SMB", "Startups", "Public sector"];

	let query = "";
	onMount(() => {
		query = window.location.search;
	});

	function list(value) {
		if (!value) return [];
		return Array.isArray(value) ? value : Array.from(value);
	}
	function setParam(name, value, blank = "All") {
		const params = new URLSearchParams(window.location.search);
		if (!value || value === blank) params.delete(name);
		else params.set(name, value);
		const next = params.toString();
		history.replaceState(null, "", next ? `${location.pathname}?${next}` : location.pathname);
		query = window.location.search;
	}
	function param(name) {
		return new URLSearchParams(query).get(name) || "";
	}
	function sum(rows, key) {
		return rows.reduce((total, row) => total + Number(row[key] || 0), 0);
	}

	$: books = list(bookings);
	$: bridges = list(bridge);
	$: currencies = list(currency);
	$: ages = list(aging);
	$: orders = list(unbilled);
	$: burns = list(burn);
	$: fresh = list(freshness);

	$: months = [...new Set(books.map((row) => isoDate(row.month_end)))].filter((month) => month && month <= "2026-08-31").sort();
	$: period = months.includes(param("period")) ? param("period") : months[months.length - 1] || "";
	$: segment = param("segment") || "All";
	$: currencyName = param("currency") || "All";
	$: sliceBits = [segment, currencyName].filter((value) => value && value !== "All");
	$: sliceText = sliceBits.length ? `${sliceBits.join(" · ")} only` : "";
	$: prior = months[months.indexOf(period) - 1] || "";

	function bookRows(month) {
		return books.filter((row) => isoDate(row.month_end) === month && (segment === "All" || row.segment === segment));
	}
	$: booked = sum(bookRows(period), "bookings_acv_usd");
	$: bookedPrior = sum(bookRows(prior), "bookings_acv_usd");
	$: flow = bridges.find((row) => isoDate(row.month_end) === period) || null;
	$: billings = flow ? Number(flow.billings_usd) : null;
	$: priorFlow = bridges.find((row) => isoDate(row.month_end) === prior) || null;
	$: unbilledAmount = flow ? Number(flow.booked_not_billed_usd) : null;
	$: shownCurrency = currencies.filter((row) => currencyName === "All" || row.currency === currencyName);
	$: unmatched = shownCurrency.reduce((total, row) => total + Number(row.unmatched_usd || 0), 0);
	$: unmatchedRatio = billings ? unmatched / billings : null;

	$: steps = flow
		? [
				{ label: "Bookings", value: Number(flow.bookings_usd), role: "open" },
				{ label: "Renewals", value: Number(flow.renewals_and_existing_usd), role: "up" },
				{ label: "Usage overage", value: Number(flow.usage_overage_usd), role: "up" },
				{ label: "Booked not billed", value: -Number(flow.booked_not_billed_usd), role: "down" },
				{ label: "Cancels", value: -Number(flow.cancels_and_credits_usd), role: "down" },
				{ label: "Billed without order", value: Number(flow.billed_without_order_usd), role: "up" },
				{ label: "Billings", value: Number(flow.billings_usd), role: "close" },
			]
		: [];

	$: currencyRows = shownCurrency.map((row) => ({
		...row,
		status: Math.abs(Number(row.unmatched_usd)) > 1000 ? "error" : Math.abs(Number(row.unmatched_usd)) > 1 ? "warn" : "pass",
	}));

	$: recent = ages.filter((row) => isoDate(row.month_end) >= "2026-03-01" && isoDate(row.month_end) <= period);
	function series(key) {
		return recent.map((row) => Number(row[key] || 0));
	}
	$: latest = recent[recent.length - 1] || {};
	$: overShare = latest.ar_usd ? Number(latest.over_90_usd || 0) / Number(latest.ar_usd) : 0;
	$: spark = [
		{ name: "Current", values: series("current_usd") },
		{ name: "1–30", values: series("bucket_1_30_usd") },
		{ name: "31–90", values: series("bucket_31_90_usd") },
		{ name: "Over 90", values: series("over_90_usd"), verdict: overShare > 0.02 ? "bad" : "" },
		{ name: "Total AR", values: series("ar_usd") },
		{
			name: "DSO",
			values: series("dso_days"),
			display: days(latest.dso_days),
			verdict: Number(latest.dso_days) > 45 ? "bad" : "",
		},
	];

	$: burnMonths = burns.filter((row) => isoDate(row.month_end).startsWith("2026-") && isoDate(row.month_end) <= period);
	$: openOrders = orders
		.filter((row) => isoDate(row.month_end) === period && (segment === "All" || row.segment === segment))
		.slice()
		.sort((a, b) => Number(b.amount_usd) - Number(a.amount_usd))
		.map((row) => ({
			name: row.account_name,
			id: row.order_id,
			description: row.segment,
			age: Number(row.age_bd),
			sla: Number(row.sla_bd),
			amount: Number(row.amount_usd),
			owner: row.owner_name,
			action: "Create invoice →",
			href: "#unbilled",
		}));

	$: filters = [
		{ label: "Currency", value: currencyName, options: ["All", ...currencies.map((row) => row.currency)], active: currencyName !== "All" },
		{ label: "Segment", value: segment, options: ["All", ...SEGMENT_ORDER], active: segment !== "All" },
	];
	$: sources = fresh.map((row) => ({
		name: row.connector === "Stripe" ? "Billing" : row.connector,
		ago: Number(row.age_hours) < 1 ? `${Math.round(Number(row.age_minutes))}m ago` : `${Math.round(Number(row.age_hours))}h ago`,
		sla: row.status === "PASS" ? "" : "24h",
		late: row.status !== "PASS",
	}));
</script>

<PageHeader
	eyebrow="Finance"
	title={monthLabel(period)}
	{sources}
	asOf={fresh[0]?.as_of_date || ""}
	note="Close snapshot 3 Sep · no restatements since"
	copyLabel="Copy link"
	exportLabel="Export for close file"
	exportRows={[{ bookings: booked, billings, booked_not_billed: unbilledAmount, unmatched }]}
>
	<SlicingBar
		slot="controls"
		periods={months.map((month) => ({ value: month, label: monthLabel(month) }))}
		{period}
		compare="prior"
		compares={[{ value: "prior", label: "Prior month" }]}
		{filters}
		context={sliceText}
		onChange={(patch) => {
			if (patch.period) setParam("period", patch.period, "");
			if (patch.filter === "Segment") setParam("segment", patch.value);
			if (patch.filter === "Currency") setParam("currency", patch.value);
		}}
	/>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Bookings" period={monthLabel(period)} value={booked} prior={bookedPrior} priorLabel={monthLabel(prior)} compareLabel="prior month" />
	<KpiTile label="Billings" period={monthLabel(period)} value={billings} prior={priorFlow ? priorFlow.billings_usd : null} priorLabel={monthLabel(prior)} compareLabel="prior month" caveat={1} />
	<KpiTile label="Booked not billed" value={unbilledAmount} plan={null} />
	<KpiTile
		label="Unmatched invoices"
		value={unmatched}
		plan={billings ? billings * 0.01 : null}
		higherIsBetter={false}
		context={unmatchedRatio == null ? "" : `${percent(unmatchedRatio)} of billings · tolerance 1%`}
	/>
</div>

<ChartBlock title="Bookings to billings, {monthLabel(period).replace(/ \d{4}$/, '')}" subtitle={sliceText || "Company"}>
	<div slot="toggle" class="inert" aria-label="Break down by">
		<button type="button" class="on">None</button>
		<button type="button">Currency</button>
	</div>
	{#if steps.length}
		<SignedBridge {steps} zeroBased />
	{:else}
		<p>No closed snapshot for this month.</p>
	{/if}
</ChartBlock>

<section class="block">
	<h2>Billings reconciliation by currency</h2>
	<table>
		<thead>
			<tr>
				<th>Currency</th>
				<th class="num">Booked</th>
				<th class="num">Billed</th>
				<th class="num">Unmatched</th>
				<th>Tie-out</th>
			</tr>
		</thead>
		<tbody>
			{#each currencyRows as row}
				<tr>
					<td>{row.currency}</td>
					<td class="num">{money(row.booked_usd)}</td>
					<td class="num">{money(row.billed_usd)}</td>
					<td class="num">{money(row.unmatched_usd)}</td>
					<td><StatusChip status={row.status} measured={money(row.unmatched_usd)} /></td>
				</tr>
			{/each}
			<tr>
				<td>Total</td>
				<td class="num">{money(sum(currencyRows, "booked_usd"))}</td>
				<td class="num">{money(sum(currencyRows, "billed_usd"))}</td>
				<td class="num">{money(unmatched)}</td>
				<td></td>
			</tr>
		</tbody>
	</table>
</section>

<div class="two-up even">
	<ChartBlock title="Receivables aging by bucket" subtitle="Mar–{monthLabel(period).slice(0, 3)}">
		<SparklineTable rows={spark} />
	</ChartBlock>
	<ChartBlock title="Usage commit burn vs straight line" subtitle={sliceText || "Company"}>
		<ActualVsPlanLine
			labels={burnMonths.map((row) => monthLabel(row.month_end))}
			actual={burnMonths.map((row) => Number(row.share_consumed))}
			plan={burnMonths.map((row) => Number(row.straight_line))}
			actualName="Consumed"
			planName="Straight line"
			format={percent}
			band="flow"
		/>
	</ChartBlock>
</div>

<section id="unbilled">
	<ChartBlock title="Booked, not billed" subtitle={sliceText || monthLabel(period)}>
		<Worklist rows={openOrders} />
	</ChartBlock>
</section>

<PageFooter
	footnotes={[{ n: 1, text: "Billing synced past its 24h SLA. Billings and unmatched invoices can still move." }]}
	definitions={[{ label: "Bookings" }, { label: "Billings" }, { label: "Booked not billed" }, { label: "DSO" }]}
	models={["fct_bookings_monthly", "fct_bookings_billings_bridge", "fct_billings_by_currency", "fct_ar_aging", "fct_commit_consumption"]}
/>

<style>
	h2 {
		margin: 0 0 12px;
		font-size: 18px;
		font-weight: 600;
	}
	.block {
		margin: 8px 0 28px;
	}
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
	}
	.num {
		text-align: right;
	}
	th.num {
		text-align: right;
	}
</style>
