<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, INK, MUTED, UNFAVORABLE, axis, axisWindow, fade, text, valueAxisTicks } from "./chartTheme.js";

	export let steps = [];
	export let zeroBased = false;
	export let height = 300;

	function anchorColor(step, truncated) {
		const hex = step.role === "close" ? FOCUS : MUTED;
		return truncated ? fade(hex) : hex;
	}

	function labelColor(step) {
		if (step.role === "close") return FOCUS;
		if (step.role !== "open" && step.value < 0) return UNFAVORABLE;
		return INK;
	}

	function labelText(step) {
		if (step.role !== "open" && step.role !== "close" && Number(step.value) === 0) return "0.0";
		if (step.role === "open" || step.role === "close") return money(step.value);
		return money(step.value, { signed: true });
	}

	$: built = (() => {
		let cursor = 0;
		const bases = [];
		const heights = [];
		const totals = [];
		for (const step of steps) {
			if (step.role === "open" || step.role === "close") cursor = Number(step.value);
			else cursor += Number(step.value);
			totals.push(cursor);
		}
		const lo = Math.min(...totals);
		const hi = Math.max(...totals);
		const window = axisWindow(lo, hi, { zero: zeroBased });
		const truncated = !zeroBased && window.min > 0;
		steps.forEach((step, i) => {
			const flat = step.role !== "open" && step.role !== "close" && Number(step.value) === 0;
			if (flat) {
				bases.push(totals[i]);
				heights.push(0);
			} else if (step.role === "open" || step.role === "close") {
				bases.push(truncated ? window.min : 0);
				heights.push(truncated ? Number(step.value) - window.min : Number(step.value));
			} else if (Number(step.value) >= 0) {
				bases.push(totals[i] - Number(step.value));
				heights.push(Number(step.value));
			} else {
				bases.push(totals[i]);
				heights.push(-Number(step.value));
			}
		});
		const zeros = steps
			.map((step, i) => ({ step, total: totals[i] }))
			.filter(({ step }) => step.role !== "open" && step.role !== "close" && Number(step.value) === 0);
		return { bases, heights, totals, window, truncated, zeros };
	})();

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: { left: 8, right: 12, top: 28, bottom: 8, containLabel: true },
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
		yAxis: valueAxisTicks(built.window, (value) => axisMoney(value)),
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
				labelLayout: { moveOverlap: "shiftY" },
				data: steps.map((step, i) => ({
					value: built.heights[i],
					itemStyle: {
						color:
							step.role === "open" || step.role === "close"
								? anchorColor(step, built.truncated)
								: Number(step.value) < 0
									? UNFAVORABLE
									: INK,
					},
					label: {
						show: built.heights[i] > 0,
						position: "top",
						distance: 4,
						formatter: () => labelText(step),
						color: labelColor(step),
						fontWeight: step.role === "close" ? 600 : 500,
						fontFamily: "IBM Plex Sans, sans-serif",
						fontSize: 12,
					},
				})),
			},
			{
				type: "line",
				data: built.totals,
				symbol: "none",
				silent: true,
				lineStyle: { type: "dashed", color: CONTEXT, width: 1 },
				z: 3,
			},
			{
				type: "scatter",
				symbol: "rect",
				symbolSize: [28, 2],
				itemStyle: { color: CONTEXT },
				data: built.zeros.map(({ step, total }) => ({
					value: [step.label, total],
					label: {
						show: true,
						formatter: "0.0",
						position: "top",
						distance: 6,
						color: MUTED,
						fontSize: 12,
						fontFamily: "IBM Plex Sans, sans-serif",
					},
				})),
				silent: true,
				z: 4,
			},
		],
	};
</script>

<ChartCanvas {option} {height} />
