<script>
	import { onMount } from "svelte";
	import ActualVsPlanLine from "./ActualVsPlanLine.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SignedBridge from "./SignedBridge.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import { BAND, dayLabel, isoDate, money, monthLabel, percent, verdict } from "./format.js";

	export let plan = [];
	export let bridge = [];
	export let movement = [];
	export let nrr = [];
	export let commentary = [];
	export let bookings = [];
	export let freshness = [];
	export let events = [];

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

	$: plans = list(plan);
	$: bridges = list(bridge);
	$: moves = list(movement);
	$: rates = list(nrr);
	$: notes = list(commentary);
	$: books = list(bookings);
	$: fresh = list(freshness);
	$: chartEvents = list(events);

	$: months = [...new Set(plans.map((row) => isoDate(row.month_end)))].filter(Boolean).sort();
	$: period = months.includes(param("period")) ? param("period") : months[months.length - 1] || "";
	$: segment = param("segment") || "All";
	$: region = param("region") || "All";
	$: hasRegion = region !== "All";
	$: sliceBits = [segment, region].filter((value) => value && value !== "All");
	$: sliceText = sliceBits.length ? `${sliceBits.join(" · ")} only` : "";

	function planRows(month) {
		return plans.filter((row) => isoDate(row.month_end) === month && (segment === "All" || row.segment === segment));
	}
	function bridgeRows(month) {
		return bridges.filter((row) => {
			if (isoDate(row.month_end) !== month) return false;
			if (segment !== "All" && row.segment !== segment) return false;
			if (region !== "All" && row.region !== region) return false;
			return true;
		});
	}

	$: prior = months[months.indexOf(period) - 1] || "";
	$: currentPlan = planRows(period);
	$: priorPlan = planRows(prior);
	$: currentBridge = bridgeRows(period);
	$: arr = hasRegion ? sum(currentBridge, "committed_arr_usd") : sum(currentPlan, "arr_usd");
	$: arrPlan = hasRegion ? null : sum(currentPlan, "arr_plan_usd");
	$: priorArr = hasRegion ? sum(bridgeRows(prior), "committed_arr_usd") : sum(priorPlan, "arr_usd");
	$: netNew = hasRegion ? null : sum(currentPlan, "net_new_usd");
	$: netNewPlan = hasRegion ? null : sum(currentPlan, "net_new_plan_usd");
	$: priorNet = hasRegion ? null : sum(priorPlan, "net_new_usd");
	$: rate = rates.find((row) => isoDate(row.month_end) === period) || {};
	$: ratePlan = currentPlan[0] || {};

	$: fyMonths = months.filter((month) => month.startsWith("2026-") && month <= period);
	$: lineActual = fyMonths.map((month) =>
		hasRegion ? sum(bridgeRows(month), "committed_arr_usd") : sum(planRows(month), "arr_usd"),
	);
	$: linePlan = fyMonths.map((month) => (hasRegion ? lineActual[fyMonths.indexOf(month)] : sum(planRows(month), "arr_plan_usd")));
	$: june = fyMonths.findIndex((month) => month.startsWith("2026-06"));
	$: eventRow = chartEvents.find((row) => row.applies_to === "arr");
	$: lineEvent = june >= 0 && eventRow ? { monthIndex: june, label: eventRow.label } : null;

	$: steps = [
		{ label: "Opening", value: sum(currentBridge, "opening_arr_usd"), role: "open" },
		{ label: "New", value: sum(currentBridge, "arr_new_usd"), role: "up" },
		{ label: "Expansion", value: sum(currentBridge, "arr_expansion_usd"), role: "up" },
		{ label: "Contraction", value: sum(currentBridge, "arr_contraction_usd"), role: "down" },
		{ label: "Churn", value: sum(currentBridge, "arr_churn_usd"), role: "down" },
		{ label: "Reactivation", value: sum(currentBridge, "arr_reactivation_usd"), role: "up" },
		{ label: "Closing", value: sum(currentBridge, "committed_arr_usd"), role: "close" },
	];

	function outside(actual, planned, band) {
		if (planned == null || planned === 0) return false;
		return Math.abs((actual - planned) / Math.abs(planned)) > BAND[band];
	}
	function noteFor(metric, seg) {
		return notes.find((row) => row.metric === metric && (row.segment || "") === (seg || ""));
	}
	function commentRow(metric, label, actual, planned, band, seg = "") {
		if (!outside(actual, planned, band) && !(metric === "bookings" && noteFor(metric, seg))) return null;
		const note = noteFor(metric, seg);
		return {
			label: seg ? `${label} · ${seg}` : label,
			delta: actual - planned,
			ratio: planned ? actual / planned - 1 : null,
			note,
			actual,
			planned,
			band,
		};
	}

	$: comments = [
		commentRow("committed_arr", "Committed ARR", arr, arrPlan, "balance"),
		...SEGMENT_ORDER.filter((name) => segment === "All" || name === segment).map((name) => {
			const rows = plans.filter((row) => isoDate(row.month_end) === period && row.segment === name);
			return commentRow("arr", "ARR", sum(rows, "arr_usd"), sum(rows, "arr_plan_usd"), "balance", name);
		}),
		...SEGMENT_ORDER.filter((name) => segment === "All" || name === segment).map((name) => {
			const rows = plans.filter((row) => isoDate(row.month_end) === period && row.segment === name);
			return commentRow("net_new", "Net new ARR", sum(rows, "net_new_usd"), sum(rows, "net_new_plan_usd"), "flow", name);
		}),
		commentRow(
			"bookings",
			"Bookings",
			sum(
				books.filter((row) => isoDate(row.month_end) === period && (segment === "All" || row.segment === segment)),
				"bookings_acv_usd",
			),
			sum(
				books.filter((row) => isoDate(row.month_end) === period && (segment === "All" || row.segment === segment)),
				"bookings_plan_usd",
			),
			"flow",
		),
	].filter(Boolean);

	const KINDS = [
		["New", "arr_new_usd"],
		["Expansion", "arr_expansion_usd"],
		["Contraction", "arr_contraction_usd"],
		["Churn", "arr_churn_usd"],
		["Reactivation", "arr_reactivation_usd"],
	];
	$: movers = moves
		.filter((row) => isoDate(row.month_end) === period && (segment === "All" || row.segment === segment) && (region === "All" || row.region === region))
		.flatMap((row) =>
			KINDS.map(([kind, key]) => ({
				name: row.account_name,
				segment: row.segment,
				kind,
				value: Number(row[key] || 0),
			})).filter((item) => item.value !== 0),
		);
	$: gains = movers.filter((item) => item.value > 0).sort((a, b) => b.value - a.value);
	$: losses = movers.filter((item) => item.value < 0).sort((a, b) => a.value - b.value);
	$: topGains = gains.slice(0, 5);
	$: topLosses = losses.slice(0, 5);
	$: moverScale = Math.max(...topGains.map((item) => item.value), ...topLosses.map((item) => Math.abs(item.value)), 1);

	$: segments = ["All", ...SEGMENT_ORDER.filter((name) => plans.some((row) => row.segment === name))];
	$: regions = ["All", ...[...new Set(bridges.map((row) => row.region).filter(Boolean))].sort()];
	$: filters = [
		{ label: "Segment", value: segment, options: segments, active: segment !== "All" },
		{ label: "Region", value: region, options: regions, active: region !== "All" },
	];
	$: periods = months.map((month) => ({ value: month, label: monthLabel(month) }));
	$: sources = fresh.map((row) => ({
		name: row.connector,
		ago: Number(row.age_hours) < 1 ? `${Math.round(Number(row.age_minutes))}m ago` : `${Math.round(Number(row.age_hours))}h ago`,
		sla: row.status === "PASS" ? "" : row.connector === "Stripe" ? "24h" : "",
		late: row.status !== "PASS",
	}));
	$: exportRows = [
		{ metric: "Committed ARR", value: arr, plan: arrPlan },
		{ metric: "Net new ARR", value: netNew, plan: netNewPlan },
		{ metric: "NRR", value: rate.nrr, plan: ratePlan.nrr_plan },
		{ metric: "GRR", value: rate.grr, plan: ratePlan.grr_plan },
	];
</script>

<PageHeader
	eyebrow="Executive"
	title={monthLabel(period)}
	{sources}
	asOf={fresh[0]?.as_of_date || ""}
	copyLabel="Copy link"
	{exportRows}
>
	<SlicingBar
		slot="controls"
		{periods}
		{period}
		compare="plan"
		compares={[{ value: "plan", label: "Plan" }]}
		{filters}
		context={sliceText}
		onChange={(patch) => {
			if (patch.period) setParam("period", patch.period, "");
			if (patch.filter === "Segment") setParam("segment", patch.value);
			if (patch.filter === "Region") setParam("region", patch.value);
		}}
	/>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Committed ARR" period={monthLabel(period)} value={arr} plan={arrPlan} prior={priorArr} priorLabel={monthLabel(prior)} />
	<KpiTile label="Net new ARR" period={monthLabel(period)} value={netNew} plan={netNewPlan} prior={priorNet} priorLabel={monthLabel(prior)} band="flow" />
	<KpiTile label="NRR (T12M)" period={sliceText ? "Company" : monthLabel(period)} value={rate.nrr} plan={ratePlan.nrr_plan} format="percent" />
	<KpiTile label="GRR (T12M)" period={sliceText ? "Company" : monthLabel(period)} value={rate.grr} plan={ratePlan.grr_plan} format="percent" />
</div>

<div class="two-up" id="arr">
	<ChartBlock title="Committed ARR vs plan, FY26" subtitle={sliceText || "Company"} definitionHref="#definitions">
		<ActualVsPlanLine labels={fyMonths} actual={lineActual} plan={linePlan} showGap={!hasRegion} event={lineEvent} />
	</ChartBlock>
	<ChartBlock title="ARR bridge, {monthLabel(period).replace(/ \d{4}$/, '')}" subtitle={sliceText || "Company"}>
		<div slot="toggle" class="inert" aria-label="Break down by">
			<button type="button" class="on">None</button>
			<button type="button">Segment</button>
			<button type="button">Region</button>
		</div>
		<SignedBridge {steps} wrapAxis />
	</ChartBlock>
</div>

<section class="block" id="commentary">
	<h2>What moved, and why</h2>
	<table>
		<thead>
			<tr>
				<th>Variance</th>
				<th>Why</th>
				<th>Owner</th>
			</tr>
		</thead>
		<tbody>
			{#each comments as row}
				<tr>
					<td>
						<div>{row.label}</div>
						<div class="num delta" style="color: {verdict(row.actual, row.planned, row.band).color}">
							{money(row.delta, { signed: true })}
							{#if row.ratio != null}· {percent(row.ratio)} of plan{/if}
						</div>
					</td>
					<td>
						{#if row.note?.commentary}
							{row.note.commentary}
							<a href="#arr">View</a>
						{:else}
							<em>
								No commentary yet.{#if row.note?.requested_on}
									Requested {dayLabel(row.note.requested_on)} due {dayLabel(row.note.due_on)}{/if}
							</em>
						{/if}
					</td>
					<td>
						{#if row.note?.author}
							{row.note.author} · {dayLabel(row.note.updated_on)}
						{/if}
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
</section>

<section class="block" id="movers">
	<h2>Top movers, {monthLabel(period).replace(/ \d{4}$/, '')}</h2>
	<div class="two-up even">
		<div>
			<p class="mover-head">Top 5: {money(topGains.reduce((t, r) => t + r.value, 0))} of {money(gains.reduce((t, r) => t + r.value, 0))}</p>
			{#each topGains as row}
				<div class="mover">
					<div>
						<div>{row.name}</div>
						<div class="meta">{row.segment} · {row.kind}</div>
					</div>
					<div class="bar gain" style="width: {(Math.abs(row.value) / moverScale) * 140}px"></div>
					<div class="num">{money(row.value, { signed: true })}</div>
				</div>
			{/each}
			<p><a href="#movers">All {gains.length} accounts with gains →</a></p>
		</div>
		<div>
			<p class="mover-head">Top 5: {money(Math.abs(topLosses.reduce((t, r) => t + r.value, 0)))} of {money(Math.abs(losses.reduce((t, r) => t + r.value, 0)))}</p>
			{#each topLosses as row}
				<div class="mover">
					<div>
						<div>{row.name}</div>
						<div class="meta">{row.segment} · {row.kind}</div>
					</div>
					<div class="bar loss" style="width: {(Math.abs(row.value) / moverScale) * 140}px"></div>
					<div class="num">{money(row.value, { signed: true })}</div>
				</div>
			{/each}
			<p><a href="#movers">All {losses.length} accounts with losses →</a></p>
		</div>
	</div>
</section>

<PageFooter
	definitions={[
		{ label: "Committed ARR" },
		{ label: "Net new ARR" },
		{ label: "NRR" },
		{ label: "GRR" },
	]}
	models={["fct_arr_monthly", "fct_arr_plan", "fct_nrr_grr", "fct_bookings_monthly"]}
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
		vertical-align: top;
	}
	.delta {
		color: var(--color-ink-muted);
		margin-top: 2px;
	}
	em {
		color: var(--color-ink-muted);
	}
	.mover-head {
		margin: 0 0 8px;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
	.mover {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 148px 88px;
		gap: 8px;
		align-items: center;
		padding: 6px 0;
		border-bottom: 1px solid var(--color-rule);
		font-size: 14px;
	}
	.meta {
		font-size: 12px;
		color: var(--color-context);
	}
	.bar {
		height: 8px;
		justify-self: end;
	}
	.bar.gain {
		background: var(--color-focus);
	}
	.bar.loss {
		background: var(--color-unfavorable);
	}
</style>
