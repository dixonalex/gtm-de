<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { BAND, axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, MUTED, RULE, UNFAVORABLE, axisWindow, text, valueAxisTicks } from "./chartTheme.js";

	export let labels = [];
	export let actual = [];
	export let plan = [];
	export let showGap = false;
	export let band = "balance";
	export let event = null;
	export let height = 280;

	const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

	function shortMonth(label) {
		const textValue = String(label ?? "");
		const named = textValue.match(/^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/);
		if (named) return named[1];
		const dated = textValue.match(/^\d{4}-(\d{2})/);
		if (dated) return MONTHS[Number(dated[1]) - 1] || textValue;
		return textValue;
	}

	function gapOutside(gap, base) {
		if (!base) return true;
		const limit = BAND[band] ?? BAND.balance;
		return Math.abs(gap / Math.abs(base)) > limit;
	}

	$: months = labels.map(shortMonth);
	$: gaps = actual.map((value, i) => value - (plan[i] || 0));
	$: last = actual.length - 1;
	$: delta = last >= 0 ? actual[last] - (plan[last] || 0) : 0;
	$: outside = last >= 0 && gapOutside(delta, plan[last]);
	$: level = axisWindow(Math.min(...actual, ...plan), Math.max(...actual, ...plan), { cover: true });
	$: gapAxis = axisWindow(Math.min(...gaps, 0), Math.max(...gaps, 0), { cover: true });
	$: eventAt = event ? shortMonth(event.at) : null;

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: showGap
			? [
					{ left: 56, right: 148, top: 12, height: "48%" },
					{ left: 56, right: 148, top: "68%", height: "16%" },
				]
			: [{ left: 56, right: 148, top: 16, bottom: 28 }],
		xAxis: (showGap ? [0, 1] : [0]).map((gridIndex) => ({
			type: "category",
			gridIndex,
			data: months,
			axisLine: { lineStyle: { color: RULE } },
			axisTick: { show: false },
			axisLabel: {
				show: !showGap || gridIndex === 1,
				color: MUTED,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
				fontSize: 12,
				interval: 0,
			},
			splitLine: { show: false },
		})),
		yAxis: [
			valueAxisTicks(level, (value) => axisMoney(value)),
			...(showGap ? [{ ...valueAxisTicks(gapAxis, (value) => axisMoney(value)), gridIndex: 1 }] : []),
		],
		series: [
			{
				name: "Plan",
				type: "line",
				data: plan,
				symbol: "none",
				lineStyle: { type: "dashed", width: 1.5, color: CONTEXT },
			},
			{
				name: "Actual",
				type: "line",
				data: actual,
				symbol: "circle",
				symbolSize: (_value, params) => (params.dataIndex === last ? 7 : 0),
				showSymbol: true,
				lineStyle: { width: 2, color: FOCUS },
				itemStyle: { color: FOCUS },
				endLabel: {
					show: true,
					distance: 10,
					formatter: () =>
						`{plan|Plan ${money(plan[last])}}\n{act|Actual ${money(actual[last])}}\n{gap|${money(delta, { signed: true })} vs plan}`,
					rich: {
						plan: {
							color: CONTEXT,
							fontSize: 12,
							fontWeight: 400,
							lineHeight: 16,
							align: "left",
							fontFamily: "IBM Plex Sans, sans-serif",
						},
						act: {
							color: FOCUS,
							fontSize: 13,
							fontWeight: 600,
							lineHeight: 18,
							align: "left",
							fontFamily: "IBM Plex Sans, sans-serif",
						},
						gap: {
							color: outside ? UNFAVORABLE : MUTED,
							fontSize: 12,
							fontWeight: 400,
							lineHeight: 16,
							align: "left",
							fontFamily: "IBM Plex Sans, sans-serif",
						},
					},
				},
				markLine: event
					? {
							symbol: "none",
							label: {
								formatter: event.label,
								color: MUTED,
								fontSize: 11,
								position: "end",
								rotate: 0,
								distance: 4,
							},
							lineStyle: { type: "dotted", color: MUTED, width: 1 },
							data: [{ xAxis: eventAt }],
						}
					: undefined,
			},
			...(showGap
				? [
						{
							name: "Gap to plan",
							type: "bar",
							xAxisIndex: 1,
							yAxisIndex: 1,
							barMaxWidth: 18,
							data: gaps.map((gap, i) => ({
								value: gap,
								itemStyle: { color: gapOutside(gap, plan[i]) ? UNFAVORABLE : CONTEXT },
								label: {
									show: true,
									position: gap < 0 ? "bottom" : "top",
									distance: 2,
									formatter: () => money(gap, { signed: true }),
									color: MUTED,
									fontSize: 11,
									fontFamily: "IBM Plex Sans, sans-serif",
								},
							})),
						},
					]
				: []),
		],
	};
</script>

<ChartCanvas {option} height={showGap ? height + 120 : height} />
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
