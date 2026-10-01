<script>
	import { onMount } from "svelte";
	import ChartCanvas from "./ChartCanvas.svelte";
	import { count } from "./format.js";
	import { FOCUS, MUTED, RULE, text } from "./chartTheme.js";
	import { mobileNow, trackNarrow } from "./narrow.js";

	export let panels = [];

	let narrow = mobileNow();
	onMount(() => trackNarrow((value) => {
		narrow = value;
	}));

	$: labels = panels[0]?.labels || [];
	$: max = Math.max(1, ...panels.flatMap((panel) => panel.values || []));
	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		title: panels.map((panel, index) => ({
			text: panel.title,
			left: 0,
			top: index * 92,
			textStyle: {
				color: MUTED,
				fontSize: 12,
				fontWeight: 500,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
			},
		})),
		grid: panels.map((_, index) => ({
			left: narrow ? 28 : 4,
			right: narrow ? 28 : 36,
			top: 18 + index * 92,
			height: 52,
		})),
		xAxis: panels.map((_, index) => ({
			type: "category",
			gridIndex: index,
			data: labels,
			axisLine: { lineStyle: { color: RULE } },
			axisTick: { show: false },
			axisLabel: {
				show: index === panels.length - 1,
				color: MUTED,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
				fontSize: 11,
				hideOverlap: false,
				interval: (i) => i === 0 || i === 14 || i === labels.length - 1,
			},
			splitLine: { show: false },
		})),
		yAxis: panels.map((_, index) => ({
			type: "value",
			gridIndex: index,
			min: 0,
			max,
			axisLabel: { show: false },
			axisLine: { show: false },
			axisTick: { show: false },
			splitLine: { show: false },
		})),
		series: panels.map((panel, index) => ({
			type: "bar",
			xAxisIndex: index,
			yAxisIndex: index,
			data: panel.values,
			barMaxWidth: 8,
			itemStyle: { color: FOCUS },
			label: {
				show: true,
				position: "top",
				formatter: (params) => (params.dataIndex === panel.values.length - 1 ? count(panel.values[panel.values.length - 1]) : ""),
				color: MUTED,
				fontSize: 12,
			},
		})),
	};
	$: height = Math.max(120, panels.length * 92 + 8);
</script>

<ChartCanvas {option} {height} />
<p class="sr">
	{#each panels as panel}
		{panel.title} {count(panel.values[panel.values.length - 1])}.
	{/each}
</p>

<style>
	.sr {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip: rect(0 0 0 0);
	}
</style>
