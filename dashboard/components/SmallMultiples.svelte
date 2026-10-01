<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { money } from "./format.js";
	import { FOCUS, MUTED, RULE, text } from "./chartTheme.js";

	export let panels = [];
	export let height = 140;

	$: max = Math.max(1, ...panels.flatMap((panel) => panel.values || []));

	function option(panel) {
		return {
			animation: false,
			textStyle: text,
			legend: { show: false },
			grid: { left: 4, right: 48, top: 8, bottom: 20 },
			xAxis: {
				type: "category",
				data: panel.labels,
				axisLine: { lineStyle: { color: RULE } },
				axisTick: { show: false },
				axisLabel: {
					color: MUTED,
					fontFamily: "IBM Plex Sans Condensed, sans-serif",
					fontSize: 11,
					interval: Math.max(0, (panel.labels || []).length - 2),
				},
				splitLine: { show: false },
			},
			yAxis: {
				type: "value",
				min: 0,
				max,
				axisLabel: { show: false },
				axisLine: { show: false },
				axisTick: { show: false },
				splitLine: { show: false },
			},
			series: [
				{
					type: "line",
					data: panel.values,
					symbol: "none",
					lineStyle: { width: 1.5, color: FOCUS },
					endLabel: {
						show: true,
						formatter: () => money(panel.values[panel.values.length - 1]),
						color: FOCUS,
						fontSize: 11,
					},
				},
			],
		};
	}
</script>

<div class="grid" style="grid-template-columns: repeat({Math.min(panels.length, 4)}, minmax(0, 1fr))">
	{#each panels as panel}
		<figure>
			<figcaption>{panel.title}</figcaption>
			<ChartCanvas option={option(panel)} {height} />
		</figure>
	{/each}
</div>

<style>
	.grid {
		display: grid;
		gap: 16px;
	}
	figure {
		margin: 0;
	}
	figcaption {
		font-family: var(--font-condensed);
		font-size: 13px;
		color: var(--color-ink-muted);
		margin-bottom: 4px;
	}
</style>
