<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { money } from "./format.js";
	import { FOCUS, MUTED, RULE, text } from "./chartTheme.js";

	export let panels = [];
	export let height = 160;

	$: max = Math.max(1, ...panels.flatMap((panel) => panel.values || []));

	function option(panel) {
		const labels = panel.labels || [];
		const values = panel.values || [];
		const last = values.length - 1;
		return {
			animation: false,
			textStyle: text,
			legend: { show: false },
			grid: { left: 4, right: 56, top: 8, bottom: 22 },
			xAxis: {
				type: "category",
				data: labels,
				axisLine: { lineStyle: { color: RULE } },
				axisTick: { show: false },
				axisLabel: {
					color: MUTED,
					fontFamily: "IBM Plex Sans Condensed, sans-serif",
					fontSize: 11,
					interval: (index) => index === 0 || index === labels.length - 1,
					hideOverlap: false,
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
					data: values,
					symbol: "none",
					lineStyle: { width: 1.5, color: FOCUS },
					endLabel: {
						show: last >= 0,
						formatter: () => money(values[last]),
						color: FOCUS,
						fontSize: 11,
						fontWeight: 500,
						distance: 6,
					},
				},
			],
		};
	}
</script>

<div class="grid" style="grid-template-columns: repeat({Math.max(panels.length, 1)}, minmax(0, 1fr))">
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
		min-width: 0;
	}
	figcaption {
		font-family: var(--font-condensed);
		font-size: 13px;
		color: var(--color-ink-muted);
		margin-bottom: 4px;
	}
</style>
