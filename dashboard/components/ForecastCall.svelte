<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, INK, MUTED, RULE, axisWindow, valueAxisTicks } from "./chartTheme.js";

	export let labels = [];
	export let commit = [];
	export let bestCase = [];
	export let quota = 0;
	export let height = 280;

	$: finite = [...commit, ...bestCase, quota].filter((value) => Number.isFinite(value));
	$: scale = axisWindow(Math.min(...finite), Math.max(...finite), { floor: 0.35 });
	$: last = Math.max(commit.length - 1, 0);

	$: option = {
		grid: { left: 64, right: 132, top: 28, bottom: 28 },
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
			{
				type: "custom",
				coordinateSystem: "cartesian2d",
				silent: true,
				z: 10,
				clip: false,
				data: [[last, commit[last], bestCase[last]]],
				renderItem(params, api) {
					const commitAt = api.coord([api.value(0), api.value(1)]);
					const bestAt = api.coord([api.value(0), api.value(2)]);
					const x = commitAt[0] + 10;
					return {
						type: "group",
						children: [
							{
								type: "text",
								style: {
									x,
									y: commitAt[1],
									text: `Commit ${money(commit[last])}`,
									fill: INK,
									fontSize: 12,
									fontWeight: 600,
									fontFamily: "IBM Plex Sans, sans-serif",
									verticalAlign: "middle",
								},
							},
							{
								type: "text",
								style: {
									x,
									y: bestAt[1],
									text: `Best case ${money(bestCase[last])}`,
									fill: MUTED,
									fontSize: 12,
									fontFamily: "IBM Plex Sans, sans-serif",
									verticalAlign: "middle",
								},
							},
						],
					};
				},
			},
		],
	};
</script>

<ChartCanvas {option} {height} />
<p class="sr">
	Commit {money(commit[last])}. Best case {money(bestCase[last])}. Quota {money(quota)}.
</p>
