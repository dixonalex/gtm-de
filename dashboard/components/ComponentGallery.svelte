<script>
	import ActualVsPlanLine from "./ActualVsPlanLine.svelte";
	import BarsWithPlanTick from "./BarsWithPlanTick.svelte";
	import BulletKpi from "./BulletKpi.svelte";
	import CaveatMarker from "./CaveatMarker.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import ReviewQueue from "./ReviewQueue.svelte";
	import SignedBridge from "./SignedBridge.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import SmallMultiples from "./SmallMultiples.svelte";
	import SparklineTable from "./SparklineTable.svelte";
	import StatusChip from "./StatusChip.svelte";
	import Worklist from "./Worklist.svelte";
	import { monthLabel } from "./format.js";

	// Fixture numbers from docs/design/screen_numbers.json (Aug 2026 extract).
	const arr = [
		104428264, 109823628, 114272149, 116596755, 118478401, 120406493, 122062048, 126248814,
	];
	const gaps = [-200000, -600000, -900000, -1400000, -1900000, -2100000, -1800000, -2400000];
	const labels = ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30", "2026-07-31", "2026-08-31"].map(
		monthLabel,
	);
	const plan = arr.map((value, i) => value - gaps[i]);

	const bridge = [
		{ label: "Opening", value: 122062048, role: "open" },
		{ label: "New", value: 3595332, role: "up" },
		{ label: "Expansion", value: 1563239, role: "up" },
		{ label: "Contraction", value: -571806, role: "down" },
		{ label: "Churn", value: -400000, role: "down" },
		{ label: "Closing", value: 126248814, role: "close" },
	];

	const shares = [
		["Enterprise", 0.48],
		["Mid-market", 0.27],
		["SMB", 0.15],
		["Public sector", 0.1],
	];
</script>

<PageHeader
	eyebrow="Component gallery"
	title="Evidence components"
	asOf="2026-09-30"
	note="August is closed. September is open."
	sources={[
		{ status: "pass", measured: "12m", threshold: "SLA 24h" },
		{ status: "warn", measured: "31h", threshold: "SLA 24h" },
	]}
		exportRows={[
		{ step: "Opening", usd: 122062048 },
		{ step: "Closing", usd: 126248814 },
	]}
>
	<CaveatMarker slot="after-title" n={1} />
	<p slot="controls" class="control-note">Controls slot</p>
</PageHeader>

<SlicingBar
	period="2026-08"
	compare="plan"
	periods={[
		{ value: "2026-07", label: "Jul 2026" },
		{ value: "2026-08", label: "Aug 2026" },
	]}
	compares={[
		{ value: "plan", label: "Plan" },
		{ value: "prior", label: "Prior period" },
	]}
	filters={[
		{ label: "Segment", value: "Enterprise", active: true, options: ["All", "Enterprise", "Mid-market"] },
		{ label: "Region", value: "All", active: false, options: ["All", "Americas", "EMEA"] },
	]}
	context="Aug 2026 · vs plan · Segment Enterprise"
/>

<section class="group">
	<h2>Status</h2>
	<div class="row">
		<StatusChip status="pass" measured="12m" threshold="SLA 24h" />
		<StatusChip status="warn" measured="31h" threshold="SLA 24h" />
		<StatusChip status="error" measured="JPY tie-out" threshold="tolerance $20K" />
		<StatusChip status="pending" measured="not run" threshold="SLA 24h" />
	</div>
</section>

<section class="group">
	<h2>KPI tile</h2>
	<div class="tiles">
		<KpiTile
			label="NRR"
			period="Aug 2026"
			value={1.028932881400198}
			plan={1.033932881400198}
			prior={1.026}
			priorLabel="Jul 2026"
			format="percent"
			band="balance"
		/>
		<KpiTile
			label="ARR"
			period="Aug 2026"
			value={126248814}
			plan={128648814}
			prior={122062048}
			priorLabel="Jul 2026"
			format="money"
			band="balance"
		/>
		<KpiTile label="DSO" period="Aug 2026" value={45.1} plan={null} format="days" band="flow" higherIsBetter={false} />
	</div>
</section>

<section class="group">
	<h2>Bullet KPI</h2>
	<div class="tiles">
		<BulletKpi label="Won, inside band" value={0.98} quota={1} band="flow" />
		<BulletKpi label="Won QTD" value={11525964} quota={14229585} band="flow" />
	</div>
</section>

<ChartBlock
	title="ARR by month, vs plan"
	subtitle="USD · Jan–Aug 2026 · company"
	definitionHref="#definitions"
>
	<p slot="toggle">Break down by segment</p>
	<ActualVsPlanLine {labels} actual={arr} {plan} showGap band="balance" event={{ label: "Close", at: "Aug 2026" }} />
</ChartBlock>

<ChartBlock title="ARR bridge, truncated axis" subtitle="USD · Aug 2026 · company" definitionHref="#definitions">
	<SignedBridge steps={bridge} zeroBased={false} />
</ChartBlock>

<ChartBlock title="ARR bridge, axis from zero" subtitle="USD · Aug 2026 · company" definitionHref="#definitions">
	<SignedBridge steps={bridge} zeroBased={true} />
</ChartBlock>

<ChartBlock title="ARR by month, vs plan" subtitle="USD · Jan–Aug 2026" definitionHref="#definitions">
	<BarsWithPlanTick
		band="balance"
		rows={labels.map((label, i) => ({
			label,
			value: arr[i],
			plan: plan[i],
			current: i === labels.length - 1,
		}))}
		height={320}
	/>
</ChartBlock>

<ChartBlock title="ARR by segment" subtitle="USD · Jan–Aug 2026 · share of company stock" definitionHref="#definitions">
	<SmallMultiples
		panels={shares.map(([title, share]) => ({
			title,
			labels,
			values: arr.map((value) => value * share),
		}))}
	/>
</ChartBlock>

<section class="group">
	<h2>Sparkline table</h2>
	<SparklineTable
		rows={[
			{ name: "Company ARR", id: "fct_arr_monthly", values: arr, verdict: "neutral" },
			{
				name: "Gap to plan",
				id: "fct_arr_plan",
				values: gaps,
				verdict: "bad",
				display: "−$2.4M",
			},
		]}
	/>
</section>

<section class="group">
	<h2>Worklist</h2>
	<Worklist
		rows={[
			{
				name: "Corvid Robotics",
				id: "006STORY",
				description: "Won without an order",
				age: 0,
				sla: 3,
				amount: 310000,
				owner: "M. Okafor",
				action: "Create order →",
			},
			{
				name: "Larkspur Energy",
				id: "006STORY",
				description: "Won without an order",
				age: 2,
				sla: 3,
				amount: 530000,
				owner: "A. Chen",
				action: "Create order →",
			},
			{
				name: "Northwind Logistics",
				id: "006STORY",
				description: "Won without an order",
				age: 9,
				sla: 3,
				amount: 412000,
				owner: "M. Okafor",
				action: "Create order →",
			},
		]}
	/>
</section>

<section class="group">
	<h2>Review queue</h2>
	<ReviewQueue
		rows={[
			{
				left: { name: "Harbor Health", domain: "harborhealth.example", country: "US", id: "001…a" },
				right: { name: "Harbor Health Inc", domain: "harborhealth.example", country: "US", id: "001…b" },
				forSignals: "Same domain, same country",
				againstSignals: "Different owner",
				arr: 412000,
				decision: "pending",
				decisionLabel: "Needs a decision",
			},
			{
				left: { name: "Kestrel Bio", domain: "kestrelbio.example", country: "US", id: "001…c" },
				right: { name: "Kestrel Biosciences", domain: "kestrel.io", country: "US", id: "001…d" },
				forSignals: "Similar name",
				againstSignals: "Different domain",
				arr: 95000,
				decision: "Reject",
				who: "A. Chen",
				when: "2026-09-12",
			},
		]}
	/>
</section>

<PageFooter
	footnotes={[
		{ n: 1, text: "August closed on 3 Sep 2026. Figures are committed ARR in USD." },
	]}
	definitions={[
		{ label: "ARR", href: "#definitions" },
		{ label: "NRR", href: "#definitions" },
		{ label: "GRR", href: "#definitions" },
	]}
	models={["fct_arr_monthly", "fct_arr_bridge", "fct_nrr_grr", "fct_ar_aging"]}
/>

<style>
	.group {
		margin: 28px 0;
	}
	.group h2 {
		margin: 0 0 12px;
		font-family: var(--font-sans);
		font-size: 18px;
		font-weight: 600;
	}
	.row,
	.tiles {
		display: flex;
		flex-wrap: wrap;
		gap: 28px;
		align-items: flex-start;
	}
	.control-note {
		margin: 0;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
</style>
