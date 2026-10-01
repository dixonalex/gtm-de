<script>
	import ChartBlock from "./ChartBlock.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import ReviewQueue from "./ReviewQueue.svelte";
	import StatusChip from "./StatusChip.svelte";
	import TestBars from "./TestBars.svelte";
	import { asRows, count, dayLabel, percent } from "./format.js";

	export let objects = [];
	export let tally = [];
	export let incidents = [];
	export let issues = [];
	export let tests = [];
	export let reviews = [];

	const FAMILIES = ["Freshness", "Relationships", "Reconciliation", "Uniqueness"];

	$: rows = asRows(objects);
	$: totals = asRows(tally)[0] || {};
	$: asideLines = [
		"Last dbt build 16:52 UTC",
		[
			`${count(totals.tests)} tests`,
			`${count(totals.pass_n)} pass`,
			`${count(totals.warn_n)} warn`,
			`${count(totals.error_n)} error`,
			Number(totals.skipped_n) ? `${count(totals.skipped_n)} skipped` : "",
		].filter(Boolean).join(" · "),
		"Next build 17:52 UTC · hourly",
	];
	$: families = FAMILIES.map((title) => {
		const key = title.toLowerCase();
		const points = asRows(tests).filter((item) => item.family === key);
		return {
			title,
			labels: points.map((item) => dayLabel(item.failed_on)),
			values: points.map((item) => Number(item.failure_count)),
		};
	});
	$: queue = asRows(reviews).map((item) => ({
		left: { name: item.name_a, domain: item.website_a, country: item.billing_country_a, id: item.account_id_a },
		right: { name: item.name_b, domain: item.website_b, country: item.billing_country_b, id: item.account_id_b },
		forSignals: item.signal_for,
		againstSignals: item.signal_against,
		arr: item.arr_at_stake_usd,
		decision: "pending",
		decisionLabel: "Decide →",
		href: "#review",
	}));

	function slaTone(item) {
		const age = Number(item.age_hours);
		const sla = Number(item.sla_hours);
		if (!(sla > 0)) return "";
		if (age > sla) return "late";
		if (age >= sla * 0.5) return "watch";
		return "";
	}

	function size(issue) {
		if (issue.size_unit === "count") return `${count(issue.size_value)} pairs`;
		return `${percent(issue.size_value)} of ${issue.issue_key === "won_without_order" ? "wins in 90 days" : issue.issue_key === "late_salesforce" ? "Salesforce rows" : "invoices"}`;
	}
</script>

<PageHeader eyebrow="DATA HEALTH · UPDATED HOURLY" title="Pipeline and tests" sources={[]} {asideLines} exportRows={rows}>
	<div slot="controls" class="slice-controls">
		<slot name="controls" />
	</div>
</PageHeader>

<section id="lineage">
	<ChartBlock title="Sources and models" subtitle="Lineage order">
		<table>
			<thead>
				<tr>
					<th>Object</th>
					<th>Status</th>
					<th>Last success</th>
					<th>Tests</th>
					<th>Feeds</th>
				</tr>
			</thead>
			<tbody>
				{#each rows as item}
					<tr>
						<td>{item.object_name}</td>
						<td>
							<StatusChip status={item.status} measured={item.status_detail || ""} />
							<span class="sr">{String(item.status).toUpperCase()}</span>
						</td>
						<td>{item.last_success || "—"}</td>
						<td>{item.test_count ? `${count(item.pass_count)} / ${count(item.test_count)}` : "—"}</td>
						<td>{item.feeds}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
</section>

<section id="incidents">
	<ChartBlock title="Open incidents" subtitle="Age vs response SLA">
		<table>
			<thead>
				<tr>
					<th>Incident</th>
					<th>Impact</th>
					<th>Open vs SLA</th>
					<th>Owner</th>
					<th class="right">Action</th>
				</tr>
			</thead>
			<tbody>
				{#each asRows(incidents) as item}
					<tr>
						<td>{item.title}</td>
						<td>{item.impact}</td>
						<td class={slaTone(item)}>{count(item.age_hours)}h / {count(item.sla_hours)}h</td>
						<td>{item.owner}</td>
						<td class="right"><a class="action" href="#incidents">{item.action} →</a></td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
</section>

<div class="two-up even">
	<ChartBlock title="Known issues backlog" subtitle="{count(asRows(issues).length)} open · no status color">
		<table>
			<thead>
				<tr>
					<th>Issue</th>
					<th>Size</th>
					<th>Handling</th>
					<th class="num">Age</th>
				</tr>
			</thead>
			<tbody>
				{#each asRows(issues) as item}
					<tr>
						<td>{item.issue_type}</td>
						<td>{size(item)}</td>
						<td>{item.handling_rule}</td>
						<td class="num">{count(item.age_days)}d</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
	<ChartBlock title="Test failures by family, last 30 days" subtitle="1–30 Sep">
		<TestBars panels={families} />
	</ChartBlock>
</div>

<ChartBlock title="Account match review queue" subtitle="Open pairs">
	<ReviewQueue rows={queue} />
</ChartBlock>

<PageFooter
	footnotes={[{ n: 1, text: "Test-failure history is simulated." }]}
	definitions={[{ label: "Connector freshness" }, { label: "Account match" }]}
	models={["rpt_health_object", "dq_account_review_queue", "rpt_known_issues"]}
/>

<style>
	table { width: 100%; border-collapse: collapse; font-size: 14px; }
	th {
		text-align: left;
		font-size: 12px;
		font-weight: 500;
		color: var(--color-ink-muted);
		border-bottom: 1px solid var(--color-ink);
		padding: 0 12px 8px 0;
	}
	td { border-bottom: 1px solid var(--color-rule); padding: 12px 12px 12px 0; vertical-align: top; }
	.num, .right { text-align: right; }
	th.num, th.right { text-align: right; }
	.late { color: var(--color-unfavorable); }
	.watch { color: var(--color-warning); }
	.action { color: var(--color-focus); text-decoration: none; }
	.sr {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip: rect(0 0 0 0);
	}
</style>
