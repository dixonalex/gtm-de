<script>
	import { money, percent, verdict } from "./format.js";

	export let label = "";
	export let period = "";
	export let value = 0;
	export let quota = 1;
	export let band = "flow";

	$: attainment = quota ? Number(value) / Number(quota) : 0;
	$: tone = verdict(attainment, 1, band, true);
	$: width = (Math.max(0, Math.min(attainment, 1.5)) / 1.5) * 100;
	$: limit = band === "balance" ? 0.01 : 0.05;
	$: bandLeft = ((1 - limit) / 1.5) * 100;
	$: bandWidth = ((2 * limit) / 1.5) * 100;
	$: gap = Number(value) - Number(quota);
	$: line =
		tone.state === "missing"
			? "No plan set"
			: `${percent(attainment)} of quota · ${money(gap, { signed: true })}`;
</script>

<article class="bullet">
	<p class="label">{label}{period ? ` · ${period}` : ""}</p>
	<p class="value num">{money(value)}</p>
	<div class="track" aria-hidden="true">
		<div class="band" style="left: {bandLeft}%; width: {bandWidth}%"></div>
		<div class="tick"></div>
		<div class="bar" style="width: {width}%"></div>
	</div>
	<div class="scale">
		<span>0%</span>
		<span class="plan">plan</span>
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
