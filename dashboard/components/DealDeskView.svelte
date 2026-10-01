<script>
	import { onMount } from "svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SlicingBar from "./SlicingBar.svelte";
	import Worklist from "./Worklist.svelte";
	import { count, dayLabel, isoDate, money } from "./format.js";

	export let exceptions = [];
	export let daily = [];
	export let freshness = [];

	const LABELS = {
		won_without_order: "Won, no order",
		invoice_unmatched: "Invoice unmatched to order",
		amount_mismatch: "Amount ≠ sum of line items",
		reduction_awaiting_approval: "Reduction order awaiting approval",
		cancelled_still_invoicing: "Cancelled order still invoicing",
	};
	const ACTIONS = {
		won_without_order: "Create order →",
		invoice_unmatched: "Match invoice →",
		amount_mismatch: "Review lines →",
		reduction_awaiting_approval: "Approve reduction →",
		cancelled_still_invoicing: "Stop invoice →",
	};

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

	$: rows = list(exceptions);
	$: snapshots = list(daily);
	$: fresh = list(freshness);
	$: today = fresh[0]?.as_of_date || "2026-09-30";
	$: owner = param("owner") || "All";
	$: type = param("type") || "All";
	$: pastOnly = param("past") === "1";
	$: sliceBits = [owner, type].filter((value) => value && value !== "All");
	$: sliceText = [pastOnly ? "Past SLA" : "", sliceBits.join(" · ")].filter(Boolean).join(" · ");
	$: sliceLine = sliceText ? `${sliceText} only` : "";

	function matches(row) {
		if (owner !== "All" && row.owner_name !== owner) return false;
		if (type !== "All" && row.exception_type !== type) return false;
		return true;
	}
	$: open = rows.filter((row) => row.is_open && matches(row));
	$: visible = open
		.filter((row) => !pastOnly || row.past_sla)
		.slice()
		.sort((a, b) => Number(b.past_sla) - Number(a.past_sla) || Number(b.amount_usd) - Number(a.amount_usd));
	$: work = visible.map((row) => ({
		name: row.account_name,
		id: row.record_id,
		description: LABELS[row.exception_type] || row.exception_type,
		age: Number(row.age_days),
		sla: Number(row.sla_bd),
		amount: Number(row.amount_usd),
		owner: row.owner_name,
		action: ACTIONS[row.exception_type] || "Review →",
		href: "#exceptions",
		caveat: row.exception_type === "invoice_unmatched" ? 1 : 0,
	}));

	$: todaySnap = snapshots.find((row) => isoDate(row.snapshot_date) === isoDate(today)) || snapshots[snapshots.length - 1] || {};
	$: yesterday = [...snapshots].filter((row) => isoDate(row.snapshot_date) < isoDate(todaySnap.snapshot_date || today)).sort((a, b) => isoDate(b.snapshot_date).localeCompare(isoDate(a.snapshot_date)))[0] || {};

	function onDay(row, key, day) {
		return isoDate(row[key]) === isoDate(day);
	}
	$: opened = rows.filter((row) => matches(row) && onDay(row, "opened_on", today));
	$: resolvedToday = rows.filter((row) => matches(row) && onDay(row, "resolved_on", today));
	$: resolved = rows
		.filter((row) => !row.is_open && matches(row) && isoDate(row.resolved_on) >= "2026-09-23" && isoDate(row.resolved_on) <= isoDate(today))
		.slice()
		.sort((a, b) => isoDate(b.resolved_on).localeCompare(isoDate(a.resolved_on)));
	$: resolvedAmount = resolved.reduce((total, row) => total + Number(row.amount_usd || 0), 0);
	$: medianAge = (() => {
		const ages = resolved.map((row) => Number(row.age_days)).sort((a, b) => a - b);
		if (!ages.length) return null;
		const mid = Math.floor(ages.length / 2);
		return ages.length % 2 ? ages[mid] : (ages[mid - 1] + ages[mid]) / 2;
	})();

	$: owners = ["All", ...[...new Set(rows.map((row) => row.owner_name).filter(Boolean))].sort()];
	$: types = ["All", ...Object.keys(LABELS)];
	$: filters = [
		{ label: "Owner", value: owner, options: owners, active: owner !== "All" },
		{
			label: "Type",
			value: type,
			options: types.map((value) => ({ value, label: value === "All" ? "All" : LABELS[value] })),
			active: type !== "All",
		},
	];
	$: sources = fresh.map((row) => ({
		name: row.connector,
		ago: Number(row.age_hours) < 1 ? `${Math.round(Number(row.age_minutes))}m ago` : `${Math.round(Number(row.age_hours))}h ago`,
		sla: row.status === "PASS" ? "" : "24h",
		late: row.status !== "PASS",
	}));
	$: titleDate = (() => {
		const d = new Date(`${isoDate(today)}T00:00:00Z`);
		const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
		return `Today · ${days[d.getUTCDay()]} ${d.getUTCDate()} ${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getUTCMonth()]}`;
	})();
</script>

<PageHeader eyebrow="Deal Desk" title={titleDate} {sources} asOf={today} copyLabel="Copy link" exportRows={work}>
	<div slot="controls" class="controls">
		<SlicingBar
			periods={[{ value: "today", label: titleDate }]}
			period="today"
			compare="yesterday"
			compares={[{ value: "yesterday", label: "Yesterday" }]}
			{filters}
			context={sliceLine}
			onChange={(patch) => {
				if (patch.filter === "Owner") setParam("owner", patch.value);
				if (patch.filter === "Type") setParam("type", patch.value);
			}}
		/>
		<button type="button" class="past" class:on={pastOnly} on:click={() => setParam("past", pastOnly ? "All" : "1")}>
			Past SLA only
		</button>
	</div>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Past SLA" value={todaySnap.past_sla_count} plan={yesterday.past_sla_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${money(todaySnap.past_sla_amount_usd)} at stake`} />
	<KpiTile label="Breach SLA tomorrow" value={todaySnap.breach_tomorrow_count} plan={yesterday.breach_tomorrow_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${money(todaySnap.breach_tomorrow_amount_usd)} at stake`} />
	<KpiTile label="Open exceptions" value={todaySnap.open_count} plan={yesterday.open_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${count(opened.length)} opened · ${count(resolvedToday.length)} resolved`} />
	<KpiTile label="USD at stake" value={todaySnap.open_amount_usd} plan={yesterday.open_amount_usd} compareLabel="yesterday" higherIsBetter={false} context={`${money(opened.reduce((t, r) => t + Number(r.amount_usd || 0), 0))} opened · ${money(resolvedToday.reduce((t, r) => t + Number(r.amount_usd || 0), 0))} resolved`} />
</div>

<section id="exceptions">
	<ChartBlock title="Open exceptions" subtitle={sliceLine || "Sorted by SLA breach, then amount"}>
		<Worklist rows={work} />
	</ChartBlock>
</section>

<details class="resolved">
	<summary>
		Resolved in the last 7 days · {count(resolved.length)} · {money(resolvedAmount)} · median {medianAge == null ? "" : `${medianAge} days`}
	</summary>
	<Worklist
		rows={resolved.map((row) => ({
			name: row.account_name,
			id: row.record_id,
			description: LABELS[row.exception_type] || row.exception_type,
			age: Number(row.age_days),
			sla: Number(row.sla_bd),
			amount: Number(row.amount_usd),
			owner: row.owner_name,
			action: "",
			caveat: row.exception_type === "invoice_unmatched" ? 1 : 0,
		}))}
	/>
</details>

<PageFooter
	footnotes={[{ n: 1, text: "Billing synced past its 24h SLA, so unmatched-invoice rows can still move." }]}
	definitions={[{ label: "Past SLA" }, { label: "Open exceptions" }]}
	models={["fct_deal_desk_exception", "fct_deal_desk_daily"]}
/>

<style>
	.controls {
		display: flex;
		flex-wrap: wrap;
		gap: 12px;
		align-items: center;
	}
	.past {
		border: 1px solid var(--color-rule);
		background: transparent;
		font: inherit;
		font-size: 13px;
		padding: 6px 10px;
		color: var(--color-ink-muted);
	}
	.past.on {
		color: var(--color-ink);
		border-color: var(--color-ink);
	}
	.resolved {
		margin: 8px 0 28px;
		font-size: 14px;
	}
	summary {
		cursor: pointer;
		margin-bottom: 12px;
	}
</style>
