<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { count } from "./format.js";
	import { FOCUS, MUTED, RULE, text } from "./chartTheme.js";

	export let panels = [];

	$: labels = panels[0]?.labels || [];
	$: max = Math.max(1, ...panels.flatMap((panel) => panel.values || []));
	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: panels.map((_, index) => ({ left: 108, right: 36, top: 8 + index * 78, height: 52 })),
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
				interval: (i) => i === 0 || i === 14 || i === labels.length - 1,
			},
			splitLine: { show: false },
		})),
		yAxis: panels.map((panel, index) => ({
			type: "value",
			gridIndex: index,
			min: 0,
			max,
			name: panel.title,
			nameLocation: "middle",
			nameGap: 8,
			nameTextStyle: { color: MUTED, fontSize: 12, align: "right" },
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
	$: height = Math.max(120, panels.length * 78 + 16);
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
