<script>
	import { onMount } from "svelte";
	import ChartCanvas from "./ChartCanvas.svelte";
	import { axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, INK, MUTED, UNFAVORABLE, axis, axisWindow, chartWidth, shortenCategory, text, valueAxisTicks } from "./chartTheme.js";
	import { mobileNow, trackNarrow } from "./narrow.js";

	export let steps = [];
	export let zeroBased = false;
	export let wrapAxis = false;

	let narrow = mobileNow();
	let layoutTick = 0;
	onMount(() => trackNarrow((value) => {
		narrow = value;
		layoutTick += 1;
	}));

	const WRAPPED = {
		Expansion: "Expan-\nsion",
		Contraction: "Contr-\naction",
		Reactivation: "Reactiv-\nation",
	};

	function tick(label) {
		if (!narrow && wrapAxis) return WRAPPED[label] || label;
		if (!narrow) return label;
		const slot = (chartWidth() - 72) / Math.max(steps.length, 1);
		return shortenCategory(label, slot - 2);
	}
	export let height = 320;

	const BAR_W = 36;

	$: barW = (() => {
		void layoutTick;
		if (!narrow) return BAR_W;
		const plot = Math.max(120, chartWidth() - 72);
		const slot = plot / Math.max(steps.length, 1);
		return Math.max(10, Math.min(BAR_W, Math.floor(slot * 0.55)));
	})();

	function isFlat(step) {
		return step.role !== "open" && step.role !== "close" && Number(step.value) === 0;
	}

	function labelColor(step) {
		if (step.role === "close") return FOCUS;
		if (step.role === "open") return MUTED;
		if (Number(step.value) < 0) return UNFAVORABLE;
		return INK;
	}

	function labelText(step) {
		if (isFlat(step)) return "0.0";
		if (step.role === "open" || step.role === "close") return money(step.value);
		return money(step.value, { signed: true });
	}

	function fadeBand(hex) {
		const r = parseInt(hex.slice(1, 3), 16);
		const g = parseInt(hex.slice(3, 5), 16);
		const b = parseInt(hex.slice(5, 7), 16);
		return {
			type: "linear",
			x: 0,
			y: 0,
			x2: 0,
			y2: 1,
			colorStops: [
				{ offset: 0, color: hex },
				{ offset: 1, color: `rgba(${r},${g},${b},0)` },
			],
		};
	}

	$: built = (() => {
		let cursor = 0;
		const totals = steps.map((step) => {
			if (step.role === "open" || step.role === "close") cursor = Number(step.value);
			else cursor += Number(step.value);
			return cursor;
		});
		const lo = Math.min(...totals);
		const hi = Math.max(...totals);
		const window = zeroBased ? axisWindow(0, hi, { zero: true }) : axisWindow(lo, hi, { floor: 0.4 });
		const truncated = !zeroBased && window.min > 0;
		const fadeY = window.min + 0.25 * (window.max - window.min);
		const bases = [];
		const fades = [];
		const bodies = [];
		steps.forEach((step, i) => {
			const value = Number(step.value);
			if ((step.role === "open" || step.role === "close") && truncated) {
				bases.push(window.min);
				fades.push(Math.max(0, fadeY - window.min));
				bodies.push(Math.max(0, value - fadeY));
			} else if (step.role === "open" || step.role === "close") {
				bases.push(0);
				fades.push(0);
				bodies.push(value);
			} else if (isFlat(step)) {
				bases.push(totals[i]);
				fades.push(0);
				bodies.push(0);
			} else if (value >= 0) {
				bases.push(totals[i] - value);
				fades.push(0);
				bodies.push(value);
			} else {
				bases.push(totals[i]);
				fades.push(0);
				bodies.push(-value);
			}
		});
		const connectors = [];
		let index = 0;
		while (index < steps.length - 1) {
			let next = index + 1;
			while (next < steps.length - 1 && isFlat(steps[next])) next += 1;
			connectors.push([index, next, totals[index]]);
			index = next;
		}
		const zeros = steps
			.map((step, i) => ({ step, total: totals[i] }))
			.filter(({ step }) => isFlat(step));
		return { bases, fades, bodies, totals, window, truncated, connectors, zeros };
	})();

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: { left: 8, right: 16, top: 28, bottom: 8, containLabel: true },
		xAxis: {
			type: "category",
			data: steps.map((step) => tick(step.label)),
			...axis,
			axisLabel: {
				...axis.axisLabel,
				interval: 0,
				hideOverlap: false,
				overflow: "none",
				lineHeight: 14,
				color: (value) => {
					const step = steps.find((item) => tick(item.label) === value);
					return step && step.role === "close" ? FOCUS : MUTED;
				},
			},
		},
		yAxis: valueAxisTicks(built.window, (value) => axisMoney(value)),
		series: [
			{
				type: "bar",
				stack: "bridge",
				barWidth: barW,
				data: built.bases,
				itemStyle: { color: "transparent" },
				emphasis: { disabled: true },
				silent: true,
			},
			{
				type: "bar",
				stack: "bridge",
				barWidth: barW,
				data: steps.map((step, i) => ({
					value: built.fades[i],
					itemStyle: {
						color:
							built.fades[i] > 0
								? fadeBand(step.role === "close" ? FOCUS : MUTED)
								: "transparent",
					},
				})),
				silent: true,
				emphasis: { disabled: true },
			},
			{
				type: "bar",
				stack: "bridge",
				barWidth: barW,
				data: steps.map((step, i) => {
					const below = step.role !== "open" && step.role !== "close" && Number(step.value) < 0;
					const anchor = step.role === "open" || step.role === "close";
					return {
						value: built.bodies[i],
						itemStyle: {
							color: anchor
								? step.role === "close"
									? FOCUS
									: MUTED
								: Number(step.value) < 0
									? UNFAVORABLE
									: INK,
						},
						label: {
							show: built.bodies[i] > 0,
							position: below ? "bottom" : "top",
							distance: below ? 10 : 8,
							formatter: () => labelText(step),
							color: labelColor(step),
							fontWeight: step.role === "close" ? 600 : 500,
							fontFamily: "IBM Plex Sans, sans-serif",
							fontSize: 12,
						},
					};
				}),
			},
			{
				type: "custom",
				coordinateSystem: "cartesian2d",
				silent: true,
				z: 3,
				data: built.connectors,
				renderItem(params, api) {
					const y = api.value(2);
					const from = api.coord([api.value(0), y]);
					const to = api.coord([api.value(1), y]);
					const half = barW / 2;
					return {
						type: "line",
						shape: {
							x1: from[0] + half,
							y1: from[1],
							x2: to[0] - half,
							y2: to[1],
						},
						style: { stroke: CONTEXT, lineWidth: 1, lineDash: [3, 3] },
					};
				},
			},
			{
				type: "scatter",
				symbol: "rect",
				symbolSize: [28, 2],
				itemStyle: { color: CONTEXT },
				data: built.zeros.map(({ step, total }) => ({
					value: [tick(step.label), total],
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
<p class="sr">
	{#each steps as step}
		{step.label} {money(step.value, { signed: step.role === "up" || step.role === "down" })}.
	{/each}
</p>
