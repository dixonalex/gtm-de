<script>
	import { RATE_BAND_PTS, money, percent } from "./format.js";

	export let label = "";
	export let period = "";
	export let value = 0;
	export let quota = 1;
	export let tickLabel = "quota";
	export let compact = false;
	export let bandPts = RATE_BAND_PTS;

	$: attainment = quota ? Number(value) / Number(quota) : 0;
	$: pts = (attainment - 1) * 100;
	$: tone =
		quota == null || quota === ""
			? { state: "missing", color: "var(--color-ink)" }
			: Math.abs(pts) <= bandPts + 1e-9
				? { state: "inside", color: "var(--color-ink)" }
				: pts > 0
					? { state: "favorable", color: "var(--color-favorable)" }
					: { state: "unfavorable", color: "var(--color-unfavorable)" };
	$: width = (Math.max(0, Math.min(attainment, 1.5)) / 1.5) * 100;
	$: limit = bandPts / 100;
	$: bandLeft = ((1 - limit) / 1.5) * 100;
	$: bandWidth = ((2 * limit) / 1.5) * 100;
	$: gap = Number(value) - Number(quota);
	$: line =
		tone.state === "missing"
			? "No plan set"
			: `${percent(attainment)} of quota · ${money(gap, { signed: true })}`;
</script>

<article class="bullet" class:compact>
	<p class="label">{label}{period ? ` · ${period}` : ""}</p>
	{#if !compact}<p class="value num">{money(value)}</p>{/if}
	<div class="track" aria-hidden="true">
		<div class="band" style="left: {bandLeft}%; width: {bandWidth}%"></div>
		<div class="tick"></div>
		<div class="bar" style="width: {width}%"></div>
	</div>
	<div class="scale">
		<span>0%</span>
		<span class="plan">{tickLabel}</span>
		<span>150%</span>
	</div>
	<p class="line num" style="color: {tone.color}">{line}</p>
</article>

<style>
	.bullet {
		min-width: 0;
		border-top: 1px solid var(--color-ink);
		padding-top: 16px;
	}
	.compact {
		border-top: 0;
		padding-top: 0;
	}
	.compact .label {
		margin-bottom: 4px;
	}
	.compact .track {
		margin-top: 4px;
	}
	.compact .scale {
		display: none;
	}
	.label {
		margin: 0 0 8px;
		font-size: 13px;
		color: var(--color-ink-muted);
	}
	.value {
		margin: 0 0 12px;
		font-size: 36px;
		line-height: 1.1;
		font-weight: 500;
		letter-spacing: -0.02em;
		color: var(--color-ink);
	}
	.track {
		position: relative;
		height: 10px;
		background: var(--color-wash);
	}
	.band {
		position: absolute;
		top: 0;
		bottom: 0;
		background: var(--color-rule);
	}
	.tick {
		position: absolute;
		top: -3px;
		bottom: -3px;
		left: 66.666%;
		width: 1px;
		background: var(--color-ink);
	}
	.bar {
		position: absolute;
		top: 2px;
		bottom: 2px;
		left: 0;
		background: var(--color-ink);
	}
	.scale {
		position: relative;
		height: 16px;
		margin-top: 4px;
		font-size: 11px;
		color: var(--color-context);
	}
	.scale span:first-child {
		position: absolute;
		left: 0;
	}
	.plan {
		position: absolute;
		left: 66.666%;
		transform: translateX(-50%);
	}
	.scale span:last-child {
		position: absolute;
		right: 0;
	}
	.line {
		margin: 8px 0 0;
		font-size: 14px;
	}
</style>
