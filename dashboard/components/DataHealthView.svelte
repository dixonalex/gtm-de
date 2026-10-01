<script>
	import { onMount } from "svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import ReviewQueue from "./ReviewQueue.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import SmallMultiples from "./SmallMultiples.svelte";
	import StatusChip from "./StatusChip.svelte";
	import Worklist from "./Worklist.svelte";
	import { count, dayLabel, isoDate, money } from "./format.js";

	export let health = [];
	export let pageMap = [];
	export let incidents = [];
	export let history = [];
	export let queue = [];
	export let tests = [];
	export let freshness = [];
	export let backlog = [];

	const RANK = { pass: 0, warn: 1, error: 2, pending: 1 };

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

	$: models = list(health);
	$: map = list(pageMap);
	$: openIncidents = list(incidents);
	$: testHistory = list(history);
	$: pairs = list(queue);
	$: results = list(tests);
	$: fresh = list(freshness);
	$: issues = list(backlog);

	$: source = param("source") || "All";
	$: model = param("model") || "All";
	$: severity = param("severity") || "All";
	$: sliceBits = [source, model, severity].filter((value) => value && value !== "All");
	$: sliceText = sliceBits.length ? `${sliceBits.join(" · ")} only` : "";

	$: order = [];
	$: {
		const seen = new Set();
		order = [];
		for (const row of map) {
			if (!seen.has(row.object_name)) {
				seen.add(row.object_name);
				order.push(row.object_name);
			}
		}
	}
	function worst(name) {
		const rows = models.filter((row) => row.object_name === name);
		return rows.sort((a, b) => (RANK[b.status] || 0) - (RANK[a.status] || 0))[0] || {};
	}
	function feeds(name) {
		return [...new Set(map.filter((row) => row.object_name === name).map((row) => row.page_name))].join(", ");
	}
	function lastSuccess(name) {
		const connector = fresh.find((row) => row.connector_id === name || row.connector?.toLowerCase() === String(name).toLowerCase());
		return connector?.last_successful_sync || "";
	}
	$: table = order
		.filter((name) => (source === "All" && model === "All") || name === source || name === model)
		.filter((name) => severity === "All" || String(worst(name).status || "").toLowerCase() === severity.toLowerCase())
		.map((name) => ({
			name,
			status: worst(name).status || "pending",
			tests: worst(name).test_status || "",
			failing: worst(name).failing_rows,
			last: lastSuccess(name),
			feeds: feeds(name),
		}));

	$: clock = results.reduce((latest, row) => (String(row.run_at) > latest ? String(row.run_at) : latest), "");
	$: warnCount = results.filter((row) => String(row.status).toLowerCase() === "warn").length;
	$: errorCount = results.filter((row) => String(row.status).toLowerCase() === "error" || String(row.status).toLowerCase() === "fail").length;
	$: nextBuild = (() => {
		const parsed = new Date(clock);
		if (Number.isNaN(parsed.getTime())) return "";
		parsed.setUTCHours(parsed.getUTCHours() + 1);
		return parsed.toISOString().slice(11, 16);
	})();

	$: incidentRows = openIncidents.map((row) => {
		const opened = new Date(row.opened_at);
		const now = clock ? new Date(clock) : opened;
		const hours = Math.max(0, (now.getTime() - opened.getTime()) / 36e5);
		return {
			name: row.title,
			id: row.incident_key,
			description: `Opened ${dayLabel(row.opened_at)}`,
			age: hours,
			sla: Number(row.sla_hours),
			ageLabel: `${hours.toFixed(1)}h / ${row.sla_hours}h`,
			amount: null,
			owner: row.owner,
			action: "Review →",
			href: "#incidents",
		};
	});

	$: families = [...new Set(testHistory.map((row) => row.family))];
	$: panels = families.map((family) => {
		const rows = testHistory.filter((row) => row.family === family).slice().sort((a, b) => isoDate(a.failed_on).localeCompare(isoDate(b.failed_on)));
		return {
			title: family,
			labels: rows.map((row) => dayLabel(row.failed_on)),
			values: rows.map((row) => Number(row.failure_count)),
		};
	});

	$: reviewRows = pairs.map((row) => ({
		left: { name: row.name_a, domain: String(row.website_a || "").replace(/^www\./, ""), country: row.billing_country_a, id: row.account_id_a },
		right: { name: row.name_b, domain: String(row.website_b || "").replace(/^www\./, ""), country: row.billing_country_b, id: row.account_id_b },
		forSignals: `Name distance ${row.name_edit_distance}`,
		againstSignals: `Match score ${Number(row.match_score).toFixed(2)}`,
		arr: row.arr_at_stake_usd,
		decision: "pending",
	}));

	$: filters = [
		{ label: "Source", value: source, options: ["All", ...order.filter((name) => map.some((row) => row.object_name === name && row.object_kind === "source"))], active: source !== "All" },
		{ label: "Model", value: model, options: ["All", ...order.filter((name) => map.some((row) => row.object_name === name && row.object_kind !== "source"))], active: model !== "All" },
		{ label: "Severity", value: severity, options: ["All", "pass", "warn", "error"], active: severity !== "All" },
	];
</script>

	<PageHeader
		eyebrow="Data health"
		title="Now · last 30 days"
		sources={[]}
		note={`Last dbt build ${clock ? clock.slice(0, 16).replace("T", " ") + " UTC" : ""} · ${count(warnCount)} warn · ${count(errorCount)} error · next build ${nextBuild} UTC`}
		copyLabel="Copy link"
		exportRows={table}
	>
	<div slot="controls">
		<SlicingBar
			periods={[{ value: "now", label: "Now · last 30 days" }]}
			period="now"
			compare="none"
			compares={[{ value: "none", label: "Current build" }]}
			{filters}
			context={sliceText}
			onChange={(patch) => {
				if (patch.filter === "Source") setParam("source", patch.value);
				if (patch.filter === "Model") setParam("model", patch.value);
				if (patch.filter === "Severity") setParam("severity", patch.value);
			}}
		/>
	</div>
</PageHeader>

<section id="lineage">
	<ChartBlock title="Sources and models" subtitle={sliceText || "Lineage order"}>
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
				{#each table as row}
					<tr>
						<td>{row.name}</td>
						<td><StatusChip status={row.status} /><span class="sr">{String(row.status).toUpperCase()}</span></td>
						<td>{row.last}</td>
						<td>{row.tests}{row.failing ? ` · ${count(row.failing)} failing` : ""}</td>
						<td>{row.feeds}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
</section>

<section id="incidents">
	<ChartBlock title="Open incidents" subtitle="Age vs response SLA">
		<Worklist rows={incidentRows} />
	</ChartBlock>
</section>

<div class="two-up even">
	<ChartBlock title="Known issues backlog" subtitle="{count(issues.length)} open · no status color">
		<table>
			<thead>
				<tr>
					<th>Issue</th>
					<th>Record</th>
					<th class="num">Age</th>
					<th class="num">At stake</th>
				</tr>
			</thead>
			<tbody>
				{#each issues.slice(0, 8) as row}
					<tr>
						<td>{row.exception_type}</td>
						<td class="id">{row.record_id}</td>
						<td class="num">{count(row.age_days)}d</td>
						<td class="num">{money(row.usd_at_stake)}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</ChartBlock>
	<ChartBlock title="Test failures by family, last 30 days" subtitle="Simulated history">
		<SmallMultiples {panels} format={(value) => count(value)} />
	</ChartBlock>
</div>

<ChartBlock title="Account match review queue" subtitle={sliceText || "Open pairs"}>
	<ReviewQueue rows={reviewRows} />
</ChartBlock>

<PageFooter
	definitions={[{ label: "Connector freshness" }, { label: "Account match" }]}
	models={["dq_model_health", "dq_account_review_queue", "dq_test_results", "Test-failure history is simulated."]}
/>

<style>
	.build {
		margin: 8px 0 0;
		font-size: 13px;
		color: var(--color-ink-muted);
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
	.plain {
		color: var(--color-ink-muted);
		font-size: 14px;
	}
</style>
