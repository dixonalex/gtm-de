<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, MUTED, RULE, axisWindow, valueAxisTicks } from "./chartTheme.js";

	export let labels = [];
	export let commit = [];
	export let bestCase = [];
	export let quota = 0;
	export let height = 280;

	$: finite = [...commit, ...bestCase, quota].filter((value) => Number.isFinite(value));
	$: scale = axisWindow(Math.min(...finite), Math.max(...finite), { floor: 0.35 });
	$: last = Math.max(commit.length - 1, 0);

	$: option = {
		grid: { left: 64, right: 16, top: 28, bottom: 28 },
		xAxis: {
			type: "category",
			data: labels,
			axisLine: { lineStyle: { color: RULE } },
			axisTick: { show: false },
			axisLabel: {
				color: MUTED,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
				fontSize: 12,
				interval: 0,
			},
			splitLine: { show: false },
		},
		yAxis: valueAxisTicks(scale, (value) => axisMoney(value)),
		series: [
			{
				name: "Commit",
				type: "line",
				data: commit,
				symbol: "none",
				lineStyle: { color: FOCUS, width: 2 },
				itemStyle: { color: FOCUS },
				markLine: {
					silent: true,
					symbol: "none",
					data: [
						{
							yAxis: quota,
							label: {
								formatter: `Quota ${money(quota)}`,
								position: "insideEndTop",
								color: CONTEXT,
								fontSize: 12,
							},
						},
					],
					lineStyle: { color: CONTEXT, type: "dashed", width: 1 },
				},
			},
			{
				name: "Best case",
				type: "line",
				data: bestCase,
				symbol: "none",
				lineStyle: { color: MUTED, width: 1.5 },
				itemStyle: { color: MUTED },
			},
		],
	};
</script>

<ChartCanvas {option} {height} />
<p class="sr">
	Commit {money(commit[last])}. Best case {money(bestCase[last])}. Quota {money(quota)}.
</p>
