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
	// Fixture numbers from docs/design/screen_numbers.json (Aug 2026 extract).
	// Bridge adds Reactivation at 0 so the zero tick is visible. Segment shares are a
	// five-way split of company ARR; the warehouse series is not queried from the gallery.
	const arr = [
		104428264, 109823628, 114272149, 116596755, 118478401, 120406493, 122062048, 126248814,
	];
	const gaps = [-200000, -600000, -900000, -1400000, -1900000, -2100000, -1800000, -2400000];
	const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"];
	const plan = arr.map((value, i) => value - gaps[i]);

	const bridge = [
		{ label: "Opening", value: 122062048, role: "open" },
		{ label: "New", value: 3595332, role: "up" },
		{ label: "Expansion", value: 1563239, role: "up" },
		{ label: "Contraction", value: -571806, role: "down" },
		{ label: "Churn", value: -400000, role: "down" },
		{ label: "Reactivation", value: 0, role: "up" },
		{ label: "Closing", value: 126248814, role: "close" },
	];

	const shares = [
		["Enterprise", 0.505],
		["Mid-market", 0.22],
		["SMB", 0.12],
		["Startups", 0.07],
		["Public sector", 0.085],
	];

	const quota = 14229585;
	const slicing = {
		period: "2026-08",
		compare: "plan",
		periods: [
			{ value: "2026-07", label: "Jul 2026" },
			{ value: "2026-08", label: "Aug 2026" },
		],
		compares: [
			{ value: "plan", label: "Plan" },
			{ value: "prior", label: "Prior period" },
		],
		filters: [
			{ label: "Segment", value: "Enterprise", active: true, options: ["All", "Enterprise", "Mid-market"] },
			{ label: "Region", value: "All", active: false, options: ["All", "Americas", "EMEA"] },
		],
		context: "Aug 2026 · vs plan · Segment Enterprise",
	};
</script>

<PageHeader
	eyebrow="Component gallery"
	title="Evidence components"
	asOf="2026-09-30"
	note="August is closed. September is open."
	sources={[
		{ name: "Salesforce", ago: "12m ago" },
		{ name: "Billing", ago: "31h ago", sla: "24h", late: true },
	]}
	exportRows={[
		{ step: "Opening", usd: 122062048 },
		{ step: "Closing", usd: 126248814 },
	]}
>
	<CaveatMarker slot="after-title" n={1} />
	<SlicingBar slot="controls" {...slicing} />
</PageHeader>

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
			label="ARR"
			period="Aug 2026"
			value={126248814}
			plan={128648814}
			prior={122062048}
			priorLabel="Jul 2026"
			format="money"
			band="balance"
		/>
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
			label="GRR"
			period="Aug 2026"
			value={0.9137}
			plan={0.9237}
			prior={0.918}
			priorLabel="Jul 2026"
			format="percent"
			band="balance"
		/>
		<KpiTile label="DSO" period="Aug 2026" value={45.1} plan={null} format="days" band="flow" higherIsBetter={false} />
	</div>
</section>

<section class="group">
	<h2>Bullet KPI</h2>
	<div class="bullets">
		<BulletKpi label="Won QTD" period="Q3 2026" value={quota * 0.98} quota={quota} band="flow" />
		<BulletKpi label="Won QTD" period="Q3 2026" value={11525964} quota={quota} band="flow" />
	</div>
</section>

<ChartBlock
	title="ARR by month, vs plan"
	subtitle="USD · Jan–Aug 2026 · company"
	definitionHref="#definitions"
>
	<p slot="toggle">Break down by segment</p>
	<ActualVsPlanLine
		labels={months}
		actual={arr}
		{plan}
		showGap
		band="balance"
		event={{ label: "Jun · Commit price change", at: "Jun" }}
	/>
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
		rows={months.map((label, i) => ({
			label,
			value: arr[i],
			plan: plan[i],
			current: i === months.length - 1,
		}))}
		height={320}
	/>
</ChartBlock>

<ChartBlock title="ARR by segment" subtitle="USD · Jan–Aug 2026 · share of company stock" definitionHref="#definitions">
	<SmallMultiples
		panels={shares.map(([title, share]) => ({
			title,
			labels: months,
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
				name: "Northwind Logistics",
				id: "006STORY0000201YHA",
				description: "Won, no order",
				age: 9,
				sla: 3,
				amount: 412000,
				owner: "M. Okafor",
				action: "Create order →",
			},
			{
				name: "Halvorsen Group",
				id: "801STORY0000202YHA",
				description: "Invoice unmatched to order",
				age: 6,
				sla: 5,
				amount: 186000,
				owner: "J. Reyes",
				action: "Match invoice →",
			},
			{
				name: "Ostrander Freight",
				id: "801STORY0000203YHA",
				description: "Cancelled order still invoicing",
				age: 4,
				sla: 2,
				amount: 128000,
				owner: "J. Reyes",
				action: "Stop billing →",
			},
			{
				name: "Larkspur Energy",
				id: "006STORY0000204YHA",
				description: "Won, no order",
				age: 2,
				sla: 3,
				amount: 530000,
				owner: "A. Chen",
				action: "Create order →",
			},
			{
				name: "Corvid Robotics",
				id: "006STORY0000205YHA",
				description: "Amount ≠ sum of line items",
				age: 0,
				sla: 3,
				amount: 310000,
				owner: "M. Okafor",
				action: "Review quote →",
			},
			{
				name: "Tidewater Health",
				id: "801STORY0000606YHA",
				description: "Reduction order awaiting approval",
				age: 1,
				sla: 5,
				amount: 240000,
				owner: "M. Okafor",
				action: "Approve →",
			},
			{
				name: "Pinecrest Media",
				id: "801STORY0000207YHA",
				description: "Invoice unmatched to order",
				age: 3,
				sla: 5,
				amount: 205000,
				owner: "J. Reyes",
				action: "Match invoice →",
			},
			{
				name: "Saltmarsh Bank",
				id: "801STORY0000608YHA",
				description: "Reduction order awaiting approval",
				age: 2,
				sla: 5,
				amount: 150000,
				owner: "A. Chen",
				action: "Approve →",
			},
			{
				name: "Kestrel Bio",
				id: "006STORY0000209YHA",
				description: "Amount ≠ sum of line items",
				age: 2,
				sla: 3,
				amount: 95000,
				owner: "A. Chen",
				action: "Review quote →",
			},
			{
				name: "Ferrow Studios",
				id: "801STORY0000210YHA",
				description: "Invoice unmatched to order",
				age: 1,
				sla: 5,
				amount: 44000,
				owner: "J. Reyes",
				action: "Match invoice →",
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
	.row {
		display: flex;
		flex-wrap: wrap;
		gap: 28px;
		align-items: flex-start;
	}
	.tiles {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 32px;
	}
	.bullets {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 32px;
	}
</style>
