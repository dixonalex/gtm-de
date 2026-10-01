<script>
	import ActualVsPlanLine from "./ActualVsPlanLine.svelte";
	import ChartBlock from "./ChartBlock.svelte";
	import KpiTile from "./KpiTile.svelte";
	import PageFooter from "./PageFooter.svelte";
	import PageHeader from "./PageHeader.svelte";
	import SignedBridge from "./SignedBridge.svelte";
	import { asRows, dayLabel, money, monthLabel, onlyLabel, percent, present, verdict } from "./format.js";

	export let kpi = [];
	export let trend = [];
	export let notes = [];
	export let movers = [];
	export let freshness = [];
	export let events = [];

	function ago(row) {
		const minutes = Number(row.age_minutes);
		if (minutes < 60) return `${Math.round(minutes)}m ago`;
		return `${Math.round(minutes / 60)}h ago`;
	}

	$: row = asRows(kpi)[0] || {};
	$: ready = present(row);
	$: series = ready ? asRows(trend) : [];
	$: comments = asRows(notes);
	$: moved = asRows(movers);
	$: gains = moved.filter((item) => item.side === "gain");
	$: losses = moved.filter((item) => item.side === "loss");
	$: eventRow = asRows(events).find((item) => item.applies_to === "arr");
	$: lineEvent = eventRow ? { at: eventRow.event_date, label: `Jun · ${eventRow.label}` } : null;
	$: sliceText = ready ? onlyLabel([row.segment, row.region]) || "Company" : "";
	$: sources = asRows(freshness)
		.slice()
		.sort((a, b) => (a.connector_id === "salesforce" ? -1 : 1))
		.map((item) => ({
			name: item.connector_id === "stripe" ? "Billing" : "Salesforce",
			ago: ago(item),
			sla: item.status === "PASS" ? "" : "24h",
			late: item.status !== "PASS",
		}));

	function bridgeSteps(item) {
		const steps = [
			{ label: "Opening", value: Number(item.opening_arr_usd), role: "open" },
			{ label: "New", value: Number(item.arr_new_usd), role: "up" },
			{ label: "Expansion", value: Number(item.arr_expansion_usd), role: "up" },
			{ label: "Contraction", value: Number(item.arr_contraction_usd), role: "down" },
			{ label: "Churn", value: Number(item.arr_churn_usd), role: "down" },
			{ label: "Reactivation", value: Number(item.arr_reactivation_usd), role: "up" },
			{ label: "Closing", value: Number(item.committed_arr_usd), role: "close" },
		];
		return steps.filter((step) => step.role === "open" || step.role === "close" || Math.abs(step.value) >= 500);
	}

	function owner(note) {
		if (!note.author) return "";
		const updated = dayLabel(note.updated_on);
		return updated ? `${note.author}, ${note.role} · ${updated}` : `${note.author}, ${note.role}`;
	}

	function placeholder(note) {
		const parts = [];
		const requested = dayLabel(note.requested_on);
		if (note.requested_from && requested) parts.push(`Requested from ${note.requested_from} on ${requested}`);
		else if (note.requested_from) parts.push(`Requested from ${note.requested_from}`);
		if (!note.author) parts.push("Unassigned");
		const due = dayLabel(note.due_on);
		if (due && !note.author) parts.push(`Due ${due}`);
		return parts.join(" · ");
	}

	function sliceName(note) {
		const names = [note.view_segment, note.view_region].filter((value) => value && value !== "All");
		return names.length ? names.join(" · ") : "the company";
	}

	function moverHead(rows) {
		const count = rows.length;
		if (!count) return "";
		const title = count < 5 ? `All ${count}` : `Top ${count}`;
		return `${title}: ${money(Math.abs(rows[0]?.top_total_usd || 0))} of ${money(Math.abs(rows[0]?.side_total_usd || 0))}`;
	}

	$: steps = bridgeSteps(row);
	$: period = monthLabel(row.month_end);
	$: periodShort = period ? period.replace(/ \d{4}$/, "") : "";
	$: prior = monthLabel(row.prior_month_end);
	$: bar = (value) => {
		const scale = Math.max(1, ...moved.map((item) => Math.abs(Number(item.net_movement_usd) || 0)));
		return (Math.abs(Number(value)) / scale) * 140;
	};
</script>

<PageHeader
	eyebrow="EXECUTIVE · MONTHLY"
	title="Revenue review"
	{sources}
	asOf={asRows(freshness)[0]?.as_of_date || ""}
	exportRows={[row]}
>
	<div slot="controls" class="slice-controls">
		<slot name="controls" />
	</div>
</PageHeader>

<div class="kpi-row">
	<KpiTile label="Committed ARR" period={ready ? period : ""} value={ready ? row.committed_arr_usd : null} plan={ready ? row.arr_plan_usd : null} prior={ready ? row.prior_arr_usd : null} priorLabel={prior} />
	<KpiTile label="Net new ARR" period={ready ? period : ""} value={ready ? row.net_new_usd : null} plan={ready ? row.net_new_plan_usd : null} prior={ready ? row.prior_net_new_usd : null} priorLabel={prior} band="flow" />
	<KpiTile label="NRR (T12M)" period={ready ? period : ""} value={ready ? row.nrr : null} plan={ready ? row.nrr_plan : null} prior={ready ? row.prior_nrr : null} priorLabel={prior} format="percent" />
	<KpiTile label="GRR (T12M)" period={ready ? period : ""} value={ready ? row.grr : null} plan={ready ? row.grr_plan : null} prior={ready ? row.prior_grr : null} priorLabel={prior} format="percent" />
</div>

<div class="two-up bridge" id="arr">
	<ChartBlock title="Committed ARR vs plan, FY26" subtitle={sliceText} definitionHref="#definitions">
		{#if ready}
			<ActualVsPlanLine
				labels={series.map((item) => item.month_key)}
				actual={series.map((item) => Number(item.committed_arr_usd))}
				plan={series.map((item) => Number(item.arr_plan_usd))}
				event={lineEvent}
				showGap
			/>
		{/if}
	</ChartBlock>
	<ChartBlock title={periodShort ? `ARR bridge, ${periodShort}` : "ARR bridge"} subtitle={sliceText}>
		<div slot="toggle" class="inert" aria-label="Break down by">
			<button type="button" class="on">None</button>
			<button type="button">Segment</button>
			<button type="button">Region</button>
		</div>
		{#if ready}<SignedBridge {steps} />{/if}
	</ChartBlock>
</div>

<section class="block" id="commentary">
	<h2>What moved, and why</h2>
	<table class="commentary">
		<thead>
			<tr>
				<th>Variance</th>
				<th>Why</th>
				<th>Owner</th>
			</tr>
		</thead>
		<tbody>
			{#each comments as note}
				<tr>
					<td>
						<div>{note.label}</div>
						<div class="num delta" style="color: {verdict(note.actual_usd, note.plan_usd, note.band).color}">
							{money(note.delta_usd, { signed: true })} vs plan · {percent(note.pct_of_plan)}
						</div>
					</td>
					<td>
						{#if note.commentary}
							{note.commentary}
							<a href="#arr">View</a>
						{:else}
							<em>
								No commentary for {sliceName(note)} yet.{#if placeholder(note)}{` ${placeholder(note)}.`}{/if}
							</em>
						{/if}
					</td>
					<td>{owner(note)}</td>
				</tr>
			{/each}
		</tbody>
	</table>
</section>

<section class="block" id="movers">
	<h2>{periodShort ? `Top movers, ${periodShort}` : "Top movers"}</h2>
	<div class="two-up even">
		<div>
			<h3>Largest gains</h3>
			<p class="mover-head">{moverHead(gains)}</p>
			{#each gains as item}
				<div class="mover">
					<div>
						<div>{item.account_name}</div>
						<div class="meta">{item.kind}</div>
					</div>
					<div class="bar gain" style="width: {bar(item.net_movement_usd)}px"></div>
					<div class="num">{money(item.net_movement_usd, { signed: true })}</div>
				</div>
			{/each}
		</div>
		<div>
			<h3>Largest losses</h3>
			<p class="mover-head">{moverHead(losses)}</p>
			{#each losses as item}
				<div class="mover">
					<div>
						<div>{item.account_name}</div>
						<div class="meta">{item.kind}</div>
					</div>
					<div class="bar loss" style="width: {bar(item.net_movement_usd)}px"></div>
					<div class="num">{money(item.net_movement_usd, { signed: true })}</div>
				</div>
			{/each}
		</div>
	</div>
</section>

<PageFooter
	definitions={[{ label: "Committed ARR" }, { label: "Net new ARR" }, { label: "NRR" }, { label: "GRR" }]}
	models={["rpt_executive_month", "fct_arr_monthly", "fct_nrr_grr"]}
/>

<style>
	h2, h3 {
		margin: 0 0 12px;
		font-size: 18px;
		font-weight: 600;
	}
	h3 {
		font-size: 14px;
	}
	.block { margin: 8px 0 28px; }
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
	.delta { margin-top: 2px; }
	em { color: var(--color-ink-muted); }
	.mover-head { margin: 0 0 8px; font-size: 13px; color: var(--color-ink-muted); }
	.mover {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 148px 88px;
		gap: 8px;
		align-items: center;
		padding: 6px 0;
		border-bottom: 1px solid var(--color-rule);
		font-size: 14px;
	}
	.meta { font-size: 12px; color: var(--color-context); }
	.bar { height: 8px; justify-self: end; }
	.bar.gain { background: var(--color-ink); }
	.bar.loss { background: var(--color-unfavorable); }
</style>
