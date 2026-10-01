<script>
	import { onMount } from "svelte";
	import ChartCanvas from "./ChartCanvas.svelte";
	import { money, percent, verdict } from "./format.js";
	import { FAVORABLE, FOCUS, INK, MUTED, UNFAVORABLE, axis, axisWindow, fitDirectLabel, measureText, text } from "./chartTheme.js";
	import { mobileNow, trackNarrow } from "./narrow.js";

	let narrow = mobileNow();
	let layoutTick = 0;
	onMount(() => trackNarrow((value) => {
		narrow = value;
		layoutTick += 1;
	}));

	export let rows = [];
	export let band = "flow";
	export let higherIsBetter = true;
	export let height = 240;

	$: peak = Math.max(1, ...rows.map((row) => Math.max(row.value || 0, row.plan || 0)));
	$: scale = axisWindow(0, peak, { zero: true });

	function barLabel(row) {
		const value = money(row.value);
		const delta = row.value - row.plan;
		const share = row.plan ? row.value / row.plan : null;
		const full = `${value} · ${money(delta, { signed: true })} · ${percent(share)} of plan`;
		return narrow ? fitDirectLabel(full, value, '400 12px "IBM Plex Sans", sans-serif') : full;
	}

	$: gutter = (() => {
		void layoutTick;
		if (!narrow) return 228;
		const widest = Math.max(48, ...rows.map((row) => measureText(barLabel(row), '600 12px "IBM Plex Sans", sans-serif')));
		return Math.ceil(widest + 16);
	})();

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: { left: 8, right: gutter, top: 8, bottom: 8, containLabel: true },
		xAxis: {
			type: "value",
			min: 0,
			max: scale.max,
			axisLine: { show: false },
			axisTick: { show: false },
			axisLabel: { show: false },
			splitLine: { show: false },
			minorSplitLine: { show: false },
			minorTick: { show: false },
		},
		yAxis: {
			type: "category",
			data: rows.map((row) => row.label),
			inverse: true,
			...axis,
			axisLabel: {
				...axis.axisLabel,
				color: (value) => {
					const row = rows.find((item) => item.label === value);
					return row && row.current ? FOCUS : MUTED;
				},
			},
		},
		series: [
			{
				type: "bar",
				barWidth: 12,
				labelLayout: { hideOverlap: false },
				data: rows.map((row) => {
					const tone = verdict(row.value, row.plan, band, higherIsBetter);
					const color = row.current
						? FOCUS
						: tone.state === "unfavorable"
							? UNFAVORABLE
							: tone.state === "favorable"
								? FAVORABLE
								: INK;
					return {
						value: Math.max(row.value, row.plan || 0),
						itemStyle: { color: "transparent" },
						label: {
							show: true,
							position: "right",
							distance: 8,
							color,
							fontSize: 12,
							fontWeight: row.current ? 600 : 400,
							fontFamily: "IBM Plex Sans, sans-serif",
							formatter: () => barLabel(row),
						},
					};
				}),
				emphasis: { disabled: true },
				z: 1,
			},
			{
				type: "bar",
				barWidth: 12,
				barGap: "-100%",
				data: rows.map((row) => ({
					value: row.value,
					itemStyle: { color: row.current ? FOCUS : MUTED },
				})),
				z: 2,
			},
			{
				type: "scatter",
				symbol: "rect",
				symbolSize: [2, 18],
				itemStyle: { color: INK },
				data: rows.map((row) => [row.plan, row.label]),
				silent: true,
				z: 4,
			},
		],
	};
</script>

<ChartCanvas {option} {height} />
