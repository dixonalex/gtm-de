<script>
	import BarsWithPlanTick from "./BarsWithPlanTick.svelte";
	import BulletKpi from "./BulletKpi.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import ForecastCall from "./ForecastCall.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SlipTable from "./SlipTable.svelte";
	import { asRows, monthLabel, onlyLabel } from "./format.js";

	export let kpi = [];
	export let segments = [];
	export let forecast = [];
	export let months = [];
	export let slips = [];
	export let freshness = [];

	function ago(row) {
		const minutes = Number(row.age_minutes);
		if (minutes < 60) return `${Math.round(minutes)}m ago`;
		return `${Math.round(minutes / 60)}h ago`;
	}

	$: row = asRows(kpi)[0] || {};
	$: call = asRows(forecast);
	$: last = call[call.length - 1] || {};
	$: sliceText = onlyLabel([row.segment, row.team, row.rep]);
	$: sources = asRows(freshness)
		.slice()
		.sort((a, b) => (a.connector_id === "salesforce" ? -1 : 1))
		.map((item) => ({
			name: item.connector_id === "stripe" ? "Billing" : "Salesforce",
			ago: ago(item),
			sla: item.status === "PASS" ? "" : "24h",
			late: item.status !== "PASS",
		}));
	$: bars = asRows(months).map((item, index, list) => ({
		label: monthLabel(item.month_end).replace(/ \d{4}$/, ""),
		value: Number(item.bookings_usd),
		plan: Number(item.bookings_plan_usd),
		current: index === list.length - 1,
	}));
</script>

<PageHeader eyebrow="SALES · WEEKLY" title="Pipeline and forecast" {sources} asOf={asRows(freshness)[0]?.as_of_date || ""} exportRows={[row]}>
	<div slot="controls" class="slice-controls">
		<slot name="controls" />
	</div>
</PageHeader>

<div class="kpi-row three">
	<BulletKpi label="Won QTD" value={row.won_usd} quota={row.quota_usd} bandPts={5} />
	<BulletKpi label="Commit" value={row.commit_usd} quota={row.quota_usd} bandPts={5} />
	<BulletKpi label="Best case" value={last.best_case_usd} quota={row.quota_usd} bandPts={5} />
</div>

<ChartBlock title="Forecast call by week vs quota" subtitle={sliceText || "Company"}>
	<ForecastCall
		labels={call.map((item) => `W${item.week_index}`)}
		commit={call.map((item) => Number(item.commit_usd))}
		bestCase={call.map((item) => Number(item.best_case_usd))}
		quota={Number(row.quota_usd)}
	/>
</ChartBlock>

<div class="two-up even">
	<ChartBlock title="Commit vs quota by segment, Q3" subtitle={sliceText || "Q3 FY26"}>
		{#each asRows(segments) as item}
			<div class="attain">
				<BulletKpi compact label={item.segment} value={item.commit_usd} quota={item.quota_usd} bandPts={5} />
			</div>
		{/each}
	</ChartBlock>
	<ChartBlock title="Bookings vs plan by month" subtitle={sliceText || "FY26 closed months"}>
		<BarsWithPlanTick rows={bars} />
	</ChartBlock>
</div>

<section id="slips">
	<ChartBlock title="Deals slipped out of Q3 this week" subtitle={sliceText || "Q3 FY26"}>
		<SlipTable rows={asRows(slips)} />
	</ChartBlock>
</section>

<PageFooter
	definitions={[{ label: "Won QTD" }, { label: "Commit" }, { label: "Best case" }]}
	models={["rpt_sales_attainment", "rpt_sales_forecast", "fct_slipped_deals"]}
/>

<style>
	.attain { margin: 0 0 14px; }
</style>
