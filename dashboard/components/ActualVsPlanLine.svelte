<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { BAND, money } from "./format.js";
	import { CONTEXT, FAVORABLE, FOCUS, INK, MUTED, RULE, UNFAVORABLE, text, valueAxis } from "./chartTheme.js";

	export let labels = [];
	export let actual = [];
	export let plan = [];
	export let showGap = false;
	export let band = "balance";
	export let higherIsBetter = true;
	export let event = null;
	export let height = 280;

	function gapColor(gap, base) {
		if (!base) return INK;
		const ratio = gap / Math.abs(base);
		const limit = BAND[band] ?? BAND.balance;
		if (Math.abs(ratio) <= limit) return INK;
		const good = higherIsBetter ? gap > 0 : gap < 0;
		return good ? FAVORABLE : UNFAVORABLE;
	}

	$: gaps = actual.map((value, i) => value - (plan[i] || 0));
	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: showGap
			? [
					{ left: 56, right: 24, top: 16, height: "52%" },
					{ left: 56, right: 24, top: "74%", height: "18%" },
				]
			: [{ left: 56, right: 72, top: 16, bottom: 28 }],
		xAxis: (showGap ? [0, 1] : [0]).map((gridIndex) => ({
			type: "category",
			gridIndex,
			data: labels,
			axisLine: { lineStyle: { color: RULE } },
			axisTick: { show: false },
			axisLabel: {
				show: !showGap || gridIndex === 1,
				color: MUTED,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
				fontSize: 12,
			},
			splitLine: { show: false },
		})),
		yAxis: [
			valueAxis((v) => money(v)),
			...(showGap
				? [
						{
							...valueAxis((v) => money(v)),
							gridIndex: 1,
						},
					]
				: []),
		].map((axis, i) => ({ ...axis, gridIndex: i })),
		series: [
			{
				name: "Plan",
				type: "line",
				data: plan,
				symbol: "none",
				lineStyle: { type: "dashed", width: 1.5, color: CONTEXT },
				endLabel: {
					show: !showGap,
					formatter: () => `Plan ${money(plan[plan.length - 1])}`,
					color: MUTED,
					fontSize: 12,
				},
				markLine: event
					? {
							symbol: "none",
							label: { formatter: event.label, color: MUTED, fontSize: 11 },
							lineStyle: { type: "dotted", color: MUTED },
							data: [{ xAxis: event.at }],
						}
					: undefined,
			},
			{
				name: "Actual",
				type: "line",
				data: actual,
				symbol: "none",
				lineStyle: { width: 2, color: FOCUS },
				itemStyle: { color: FOCUS },
				endLabel: {
					show: !showGap,
					formatter: () => money(actual[actual.length - 1]),
					color: FOCUS,
					fontSize: 12,
					fontWeight: 600,
				},
			},
			...(showGap
				? [
						{
							name: "Gap to plan",
							type: "bar",
							xAxisIndex: 1,
							yAxisIndex: 1,
							data: gaps.map((gap, i) => ({
								value: gap,
								itemStyle: { color: gapColor(gap, plan[i]) },
							})),
							barMaxWidth: 18,
						},
					]
				: []),
		],
	};
</script>

<ChartCanvas {option} height={showGap ? height + 80 : height} />
<p class="sr">Actual and plan. {#if showGap}Gap to plan underneath.{/if}</p>

<style>
	.sr {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip: rect(0 0 0 0);
	}
</style>
