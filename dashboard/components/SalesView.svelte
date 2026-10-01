<script>
	import { onMount } from "svelte";
	import BarsWithPlanTick from "./BarsWithPlanTick.svelte";
	import BulletKpi from "./BulletKpi.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import ForecastCall from "./ForecastCall.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import Worklist from "./Worklist.svelte";
	import { dayLabel, isoDate, money, monthLabel } from "./format.js";

	export let bookings = [];
	export let forecast = [];
	export let quota = [];
	export let slips = [];
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
	$: calls = list(forecast);
	$: quotas = list(quota);
	$: slipped = list(slips);
	$: fresh = list(freshness);

	$: week = Number(param("week") || calls[calls.length - 1]?.week_index || 13);
	$: segment = param("segment") || "All";
	$: rep = param("rep") || "All";
	$: sliceBits = [segment, rep].filter((value) => value && value !== "All");
	$: sliceText = sliceBits.length ? `${sliceBits.join(" · ")} only` : "";

	$: q3 = books.filter(
		(row) => isoDate(row.month_end) >= "2026-07-01" && isoDate(row.month_end) <= "2026-09-30" && (segment === "All" || row.segment === segment),
	);
	$: won = sum(q3, "bookings_acv_usd");
	$: quotaRows = quotas.filter((row) => segment === "All" || row.segment === segment);
	$: quotaTotal = sum(quotaRows, "quota_usd");
	$: call = calls.find((row) => Number(row.week_index) === week) || calls[calls.length - 1] || {};
	$: through = calls.filter((row) => Number(row.week_index) <= week);

	$: attainment = SEGMENT_ORDER.filter((name) => segment === "All" || name === segment).map((name) => ({
		label: name,
		value: sum(
			books.filter((row) => isoDate(row.month_end) >= "2026-07-01" && isoDate(row.month_end) <= "2026-09-30" && row.segment === name),
			"bookings_acv_usd",
		),
		quota: sum(quotas.filter((row) => row.segment === name), "quota_usd"),
	}));

	$: barMonths = [...new Set(books.map((row) => isoDate(row.month_end)))].filter((month) => month.startsWith("2026-") && month <= "2026-08-31").sort();
	$: bars = barMonths.map((month) => {
		const rows = books.filter((row) => isoDate(row.month_end) === month && (segment === "All" || row.segment === segment));
		return {
			label: monthLabel(month).slice(0, 3),
			value: sum(rows, "bookings_acv_usd"),
			plan: sum(rows, "bookings_plan_usd"),
			current: month.startsWith("2026-08"),
		};
	});

	$: slipRows = slipped
		.filter((row) => (segment === "All" || row.segment === segment) && (rep === "All" || row.owner_name === rep))
		.map((row) => ({
			name: row.account_name,
			id: row.opportunity_id,
			description: `${row.segment} · ${dayLabel(row.previous_close_date)} → ${dayLabel(row.close_date)}`,
			age: Number(row.slip_count),
			sla: 3,
			ageLabel: `${Math.round(Number(row.slip_count))} slips`,
			amount: Number(row.amount_usd),
			owner: row.owner_name,
			action: "Review →",
			href: "#slips",
		}));

	$: reps = ["All", ...[...new Set(slipped.map((row) => row.owner_name).filter(Boolean))].sort()];
	$: filters = [
		{ label: "Segment", value: segment, options: ["All", ...SEGMENT_ORDER], active: segment !== "All" },
		{ label: "Team", value: "All", options: ["All"], active: false },
		{ label: "Rep", value: rep, options: reps, active: rep !== "All" },
	];
	$: periods = calls.map((row) => ({ value: String(row.week_index), label: `Q3 FY26 · week ${row.week_index}` }));
	$: sources = fresh.map((row) => ({
		name: row.connector,
		ago: Number(row.age_hours) < 1 ? `${Math.round(Number(row.age_minutes))}m ago` : `${Math.round(Number(row.age_hours))}h ago`,
		sla: row.status === "PASS" ? "" : "24h",
		late: row.status !== "PASS",
	}));
</script>

<PageHeader eyebrow="Sales" title="Q3 FY26" {sources} asOf={fresh[0]?.as_of_date || ""} copyLabel="Copy link" exportRows={[{ won, quota: quotaTotal, commit: call.commit_usd, best_case: call.best_case_usd }]}>
	<SlicingBar
		slot="controls"
		{periods}
		period={String(week)}
		compare="quota"
		compares={[{ value: "quota", label: "Quota" }]}
		{filters}
		context={sliceText}
		onChange={(patch) => {
			if (patch.period) setParam("week", patch.period, "");
			if (patch.filter === "Segment") setParam("segment", patch.value);
			if (patch.filter === "Rep") setParam("rep", patch.value);
		}}
	/>
</PageHeader>

<div class="kpi-row three">
	<BulletKpi label="Won QTD" value={won} quota={quotaTotal} />
	<BulletKpi label="Commit" value={call.commit_usd} quota={quotaTotal} />
	<BulletKpi label="Best case" value={call.best_case_usd} quota={quotaTotal} />
</div>

<ChartBlock title="Forecast call by week vs quota" subtitle={sliceText ? `${sliceText}. Call is company-wide.` : "Company"}>
	<ForecastCall
		labels={through.map((row) => `W${row.week_index}`)}
		commit={through.map((row) => Number(row.commit_usd))}
		bestCase={through.map((row) => Number(row.best_case_usd))}
		quota={quotaTotal}
	/>
</ChartBlock>

<div class="two-up even">
	<ChartBlock title="Attainment by segment" subtitle={sliceText || "Q3 FY26"}>
		{#each attainment as row}
			<div class="attain">
				<BulletKpi label={row.label} value={row.value} quota={row.quota} />
			</div>
		{/each}
	</ChartBlock>
	<ChartBlock title="Bookings vs plan by month" subtitle={sliceText || "FY26 closed months"}>
		<BarsWithPlanTick rows={bars} />
	</ChartBlock>
</div>

<section id="slips">
	<ChartBlock title="Deals slipped out of Q3 this week" subtitle={sliceText || "Q3 FY26"}>
		<Worklist rows={slipRows} />
	</ChartBlock>
</section>

<PageFooter
	definitions={[{ label: "Won QTD" }, { label: "Commit" }, { label: "Best case" }]}
	models={["fct_bookings_monthly", "fct_forecast_call", "fct_slipped_deals"]}
/>

<style>
	.attain {
		margin-bottom: 16px;
	}
</style>
