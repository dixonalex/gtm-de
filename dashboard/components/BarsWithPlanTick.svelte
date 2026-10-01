<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { money, percent, verdict } from "./format.js";
	import { FOCUS, INK, MUTED, RULE, axis, text } from "./chartTheme.js";

	export let rows = [];
	export let band = "flow";
	export let higherIsBetter = true;
	export let height = 240;

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: { left: 8, right: 148, top: 8, bottom: 8, containLabel: true },
		xAxis: {
			type: "value",
			splitNumber: 2,
			axisLine: { show: false },
			axisTick: { show: false },
			axisLabel: { show: false },
			splitLine: { show: true, lineStyle: { color: RULE, width: 1 } },
		},
		yAxis: {
			type: "category",
			data: rows.map((row) => row.label),
			inverse: true,
			...axis,
			axisLabel: {
				...axis.axisLabel,
				color: MUTED,
			},
		},
		series: [
			{
				type: "bar",
				barMaxWidth: 14,
				data: rows.map((row) => {
					const tone = verdict(row.value, row.plan, band, higherIsBetter);
					const delta = row.value - row.plan;
					const share = row.plan ? row.value / row.plan : null;
					return {
						value: row.value,
						itemStyle: { color: row.current ? FOCUS : MUTED },
						label: {
							show: true,
							position: "right",
							distance: 8,
							color: tone.color,
							fontSize: 12,
							fontFamily: "IBM Plex Sans, sans-serif",
							formatter: () =>
								`${money(row.value)} · ${money(delta, { signed: true })} · ${percent(share)} of plan`,
						},
					};
				}),
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
