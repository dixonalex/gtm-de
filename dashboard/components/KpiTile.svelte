<script>
	import CaveatMarker from "./CaveatMarker.svelte";
	import { formatDelta, formatValue, percent, sameYearLabel, verdict, verdictRate } from "./format.js";

	export let label = "";
	export let period = "";
	export let value = null;
	export let plan = null;
	export let prior = null;
	export let priorLabel = "prior period";
	export let format = "money";
	export let band = "balance";
	export let higherIsBetter = true;
	export let context = "";
	export let compareLabel = "plan";
	export let caveat = 0;
	export let verdictText = "";
	export let verdictColor = "";

	$: tone = format === "percent" ? verdictRate(value, plan, higherIsBetter) : verdict(value, plan, band, higherIsBetter);
	$: vsPlan =
		format === "money" && plan != null && plan !== "" && compareLabel === "plan"
			? `${formatDelta(value, plan, format)} · ${percent(Number(value) / Number(plan))}`
			: formatDelta(value, plan, format);
	$: vsCompare = (plan == null || plan === "" ? vsPrior : vsPlan).replace("vs plan", `vs ${compareLabel}`);
	$: contextLine = plan == null || plan === "" ? context : context || vsPrior;
	$: vsPrior =
		prior == null || prior === ""
			? ""
			: formatDelta(value, prior, format).replace("vs plan", `vs ${sameYearLabel(priorLabel, period)}`);
</script>

<article class="tile" data-kpi={label}>
	<p class="label">{label}{period ? ` · ${period}` : ""}{#if caveat}<CaveatMarker n={caveat} />{/if}</p>
	<p class="value num">{formatValue(value, format)}</p>
	<p class="verdict num" style="color: {verdictColor || tone.color}">{verdictText || vsCompare}</p>
	<p class="context num">{contextLine}</p>
</article>

<style>
	.tile {
		min-width: 0;
		border-top: 1px solid var(--color-ink);
		padding-top: 16px;
	}
	.label {
		margin: 0 0 8px;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
	.value {
		margin: 0;
		font-size: 36px;
		line-height: 1.1;
		font-weight: 500;
		letter-spacing: -0.02em;
		color: var(--color-ink);
	}
	.verdict {
		margin: 8px 0 0;
		font-size: 14px;
		line-height: 1.3;
	}
	.context {
		margin: 4px 0 0;
		font-size: 13px;
		line-height: 1.3;
		color: var(--color-ink-muted);
		min-height: 1.3em;
	}
</style>
