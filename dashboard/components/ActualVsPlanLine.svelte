<script>
	import ChartCanvas from "./ChartCanvas.svelte";
	import { BAND, axisMoney, money, points } from "./format.js";
	import { CONTEXT, FOCUS, MUTED, RULE, UNFAVORABLE, axisWindow, text, valueAxisTicks } from "./chartTheme.js";

	export let labels = [];
	export let actual = [];
	export let plan = [];
	export let showGap = false;
	export let band = "balance";
	export let event = null;
	export let height = 280;
	export let actualName = "Actual";
	export let planName = "Plan";
	export let format = money;
	export let axisFormat = axisMoney;
	export let yDomain = null;
	export let pointGap = false;

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
	$: gapPts = last >= 0 ? (actual[last] - plan[last]) * 100 : 0;
	$: outside = pointGap ? Math.abs(gapPts) > 5 + 1e-9 : last >= 0 && gapOutside(delta, plan[last]);
	$: level = yDomain || axisWindow(Math.min(...actual, ...plan), Math.max(...actual, ...plan));
	$: gapAxis = (() => {
		const window = axisWindow(Math.min(...gaps, 0), Math.max(...gaps, 0));
		const step = window.ticks.length > 1 ? Math.abs(window.ticks[1] - window.ticks[0]) : 1;
		return { ...window, min: window.ticks[0] - step * 0.55 };
	})();
	$: eventAt = event ? shortMonth(event.at) : null;

	$: option = {
		animation: false,
		textStyle: text,
		legend: { show: false },
		grid: showGap
			? [
					{ left: 56, right: 168, top: 36, height: "40%" },
					{ left: 56, right: 168, top: "64%", bottom: 28 },
				]
			: [{ left: 56, right: 168, top: 48, bottom: 28 }],
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
			valueAxisTicks(level, (value) => axisFormat(value)),
			...(showGap ? [{ ...valueAxisTicks(gapAxis, (value) => axisMoney(value)), gridIndex: 1 }] : []),
		],
		series: [
			{
				name: planName,
				type: "line",
				data: plan,
				symbol: "none",
				lineStyle: { type: "dashed", width: 1.5, color: CONTEXT },
			},
			{
				name: actualName,
				type: "line",
				data: actual,
				symbol: "circle",
				symbolSize: (_value, params) => (params.dataIndex === last ? 7 : 0),
				showSymbol: true,
				lineStyle: { width: 2, color: FOCUS },
				itemStyle: { color: FOCUS },
				markLine: event
					? {
							symbol: "none",
							label: {
								formatter: event.label,
								color: MUTED,
								fontSize: 11,
								position: "end",
								rotate: 0,
								distance: 8,
							},
							lineStyle: { type: "dotted", color: MUTED, width: 1 },
							data: [{ xAxis: eventAt }],
						}
					: undefined,
			},
			{
				type: "custom",
				coordinateSystem: "cartesian2d",
				silent: true,
				z: 10,
				clip: false,
				data: [[last, plan[last], actual[last]]],
				renderItem(params, api) {
					const at = api.coord([api.value(0), api.value(1)]);
					const planY = at[1];
					const actY = api.coord([api.value(0), api.value(2)])[1];
					const x = at[0] + 14;
					const upper = Math.min(planY, actY);
					const lower = Math.max(planY, actY);
					const lineH = 16;
					// The text anchor is the vertical center, so pad by half a line.
					const planTop = upper - 6 - lineH;
					const actualTop = lower + 6 + lineH / 2;
					const rows = [
						{ text: `${planName} ${format(plan[last])}`, y: planTop, fill: CONTEXT, weight: 400, size: 12 },
						{ text: `${actualName} ${format(actual[last])}`, y: actualTop, fill: FOCUS, weight: 600, size: 13 },
						{
							text: pointGap ? points(gapPts) : `${money(delta, { signed: true })} vs plan`,
							y: actualTop + lineH,
							fill: outside ? UNFAVORABLE : MUTED,
							weight: 400,
							size: 12,
						},
					];
					return {
						type: "group",
						children: rows.map((row) => ({
							type: "text",
							style: {
								x,
								y: row.y,
								text: row.text,
								fill: row.fill,
								fontSize: row.size,
								fontWeight: row.weight,
								fontFamily: "IBM Plex Sans, sans-serif",
								verticalAlign: "top",
								align: "left",
							},
						})),
					};
				},
			},
			...(showGap
				? [
						{
							name: "Gap to plan",
							type: "bar",
							xAxisIndex: 1,
							yAxisIndex: 1,
							barMaxWidth: 18,
							labelLayout: { moveOverlap: "shiftY", hideOverlap: false },
							data: gaps.map((gap, i) => ({
								value: gap,
								itemStyle: { color: gapOutside(gap, plan[i]) ? UNFAVORABLE : CONTEXT },
								label: {
									show: true,
									position: "top",
									distance: 2,
									rotate: 0,
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
<p class="sr">
	{actualName} {format(actual[actual.length - 1])}. {planName} {format(plan[plan.length - 1])}.
	{#if pointGap}Gap {points(gapPts)}.{:else if showGap}Gap {money(actual[actual.length - 1] - plan[plan.length - 1], { signed: true })}.{/if}
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
