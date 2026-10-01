<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { money } from "./format.js";
	import { FOCUS, INK, MUTED, RULE, UNFAVORABLE, axis, fade, text, valueAxis } from "./chartTheme.js";

	export let steps = [];
	export let zeroBased = false;
	export let height = 300;

	function colorFor(step, truncated) {
		if (step.role === "open") return truncated ? fade(MUTED) : MUTED;
		if (step.role === "close") return truncated ? fade(FOCUS) : FOCUS;
		if (step.value < 0) return UNFAVORABLE;
		return INK;
	}

	$: built = (() => {
		let cursor = 0;
		const bases = [];
		const heights = [];
		const totals = [];
		for (const step of steps) {
			if (step.role === "open") {
				bases.push(0);
				heights.push(step.value);
				cursor = step.value;
			} else if (step.role === "close") {
				bases.push(0);
				heights.push(step.value);
				cursor = step.value;
			} else if (step.value >= 0) {
				bases.push(cursor);
				heights.push(step.value);
				cursor += step.value;
			} else {
				cursor += step.value;
				bases.push(cursor);
				heights.push(-step.value);
			}
			totals.push(cursor);
		}
		const low = Math.min(...bases.filter((_, i) => heights[i] > 0), ...totals);
		const axisMin = zeroBased ? 0 : Math.max(0, low * 0.9);
		const truncated = axisMin > 0;
		return { bases, heights, totals, axisMin, truncated };
	})();

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: { left: 8, right: 8, top: 28, bottom: 32, containLabel: true },
		xAxis: {
			type: "category",
			data: steps.map((step) => step.label),
			...axis,
			axisLabel: {
				...axis.axisLabel,
				interval: 0,
				color: (value) => {
					const step = steps.find((item) => item.label === value);
					return step && step.role === "close" ? FOCUS : MUTED;
				},
			},
		},
		yAxis: {
			...valueAxis((v) => money(v)),
			min: built.axisMin,
			axisLabel: { show: false },
			splitLine: { show: true, lineStyle: { color: RULE, width: 1 } },
			splitNumber: 2,
		},
		series: [
			{
				type: "bar",
				stack: "bridge",
				data: built.bases,
				itemStyle: { color: "transparent" },
				emphasis: { disabled: true },
				silent: true,
			},
			{
				type: "bar",
				stack: "bridge",
				barMaxWidth: 36,
				data: steps.map((step, i) => ({
					value: built.heights[i],
					itemStyle: { color: colorFor(step, built.truncated) },
					label: {
						show: true,
						position: "top",
						formatter: () =>
							step.role === "open" || step.role === "close"
								? money(step.value)
								: money(step.value, { signed: true }),
						color: INK,
						fontFamily: "IBM Plex Sans, sans-serif",
						fontSize: 11,
					},
				})),
			},
			{
				type: "line",
				data: built.totals,
				symbol: "none",
				silent: true,
				lineStyle: { type: "dashed", color: RULE, width: 1 },
				z: 3,
			},
		],
	};
</script>

<ChartCanvas {option} {height} />
