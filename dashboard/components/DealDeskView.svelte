<script>
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import Worklist from "./Worklist.svelte";
	import { asRows, count, money, onlyLabel } from "./format.js";

	export let kpi = [];
	export let openRows = [];
	export let resolvedRows = [];
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
		cancelled_still_invoicing: "Stop invoice →",
		reduction_awaiting_approval: "Approve reduction →",
		amount_mismatch: "Review lines →",
	};

	function ago(row) {
		const minutes = Number(row.age_minutes);
		if (minutes < 60) return `${Math.round(minutes)}m ago`;
		return `${Math.round(minutes / 60)}h ago`;
	}

	function toWork(row) {
		return {
			name: row.account_name,
			id: row.record_id,
			description: LABELS[row.exception_type] || row.exception_type,
			age: Number(row.age_days),
			sla: Number(row.sla_bd),
			amount: Number(row.amount_usd),
			owner: row.owner_name,
			action: ACTIONS[row.exception_type] || "Open record →",
			href: "#exceptions",
			caveat: row.exception_type === "invoice_unmatched" ? 1 : 0,
		};
	}

	$: row = asRows(kpi)[0] || {};
	$: sliceText = onlyLabel([row.owner_name, LABELS[row.exception_type] || row.exception_type]);
	$: sources = asRows(freshness)
		.slice()
		.sort((a, b) => (a.connector_id === "salesforce" ? -1 : 1))
		.map((item) => ({
			name: item.connector_id === "stripe" ? "Billing" : "Salesforce",
			ago: ago(item),
			sla: item.status === "PASS" ? "" : "24h",
			late: item.status !== "PASS",
		}));
	$: resolvedLine = `${count(row.resolved_count)} exceptions, ${money(row.resolved_amount_usd)} · median ${Number(row.resolved_median_days).toFixed(1)} days to resolve · ${count(row.resolved_past_sla_count)} resolved past SLA`;
</script>

<PageHeader eyebrow="DEAL DESK · DAILY" title="Quote-to-cash exceptions" {sources} asOf={asRows(freshness)[0]?.as_of_date || ""} exportRows={asRows(openRows)}>
	<div slot="controls" class="slice-controls">
		<slot name="controls" />
	</div>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Past SLA" value={row.past_sla_count} plan={row.yesterday_past_sla_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${money(row.past_sla_amount_usd)} at stake`} />
	<KpiTile label="Breach SLA tomorrow" value={row.breach_tomorrow_count} plan={row.yesterday_breach_tomorrow_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${money(row.breach_tomorrow_amount_usd)} at stake`} />
	<KpiTile label="Open exceptions" value={row.open_count} plan={row.yesterday_open_count} format="count" compareLabel="yesterday" higherIsBetter={false} context={`${count(row.opened_count)} opened · ${count(row.resolved_today_count)} resolved`} />
	<KpiTile label="USD at stake" value={row.open_amount_usd} plan={row.yesterday_open_amount_usd} compareLabel="yesterday" higherIsBetter={false} context={`${money(row.opened_amount_usd)} opened · ${money(row.resolved_today_amount_usd)} resolved`} />
</div>

<section id="exceptions">
	<ChartBlock title="Open exceptions" subtitle={sliceText || "Sorted by SLA breach, then amount"}>
		<Worklist rows={asRows(openRows).map(toWork)} />
	</ChartBlock>
</section>

<details class="resolved">
	<summary>Resolved in the last 7 days · {resolvedLine}</summary>
	<Worklist rows={asRows(resolvedRows).map(toWork)} />
</details>

<PageFooter
	footnotes={[{ n: 1, text: "Billing synced past its 24h SLA, so unmatched-invoice rows can still move." }]}
	definitions={[{ label: "Past SLA" }, { label: "Open exceptions" }]}
	models={["rpt_deal_desk_slice", "fct_deal_desk_exception"]}
/>

<style>
	.resolved { margin: 8px 0 28px; font-size: 14px; }
	summary { cursor: pointer; margin-bottom: 12px; }
</style>
