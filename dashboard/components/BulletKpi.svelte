<script>
	import { BAND, percent, points, verdict } from "./format.js";

	export let label = "";
	export let value = 0;
	export let quota = 1;
	export let band = "flow";

	$: attainment = quota ? Number(value) / Number(quota) : 0;
	$: tone = verdict(attainment, 1, band, true);
	$: width = Math.max(0, Math.min(attainment, 1.5)) / 1.5 * 100;
	$: limit = BAND[band] ?? BAND.flow;
	$: bandLeft = ((1 - limit) / 1.5) * 100;
	$: bandWidth = ((2 * limit) / 1.5) * 100;
	$: line =
		tone.state === "missing"
			? "No plan set"
			: `${percent(attainment)} of quota · ${points((attainment - 1) * 100)}`;
</script>

<article class="bullet">
	<p class="label">{label}</p>
	<div class="track" aria-hidden="true">
		<div class="band" style="left: {bandLeft}%; width: {bandWidth}%"></div>
		<div class="tick"></div>
		<div class="bar" style="width: {width}%"></div>
	</div>
	<p class="line num" style="color: {tone.color}">{line}</p>
</article>

<style>
	.bullet {
		min-width: 220px;
	}
	.label {
		margin: 0 0 8px;
		font-size: 13px;
		color: var(--color-ink-muted);
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
	.line {
		margin: 8px 0 0;
		font-size: 14px;
	}
</style>
