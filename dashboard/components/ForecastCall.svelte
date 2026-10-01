<script>
	import { onMount } from "svelte";
	import ChartCanvas from "./ChartCanvas.svelte";
	import { axisMoney, money } from "./format.js";
	import { CONTEXT, FOCUS, INK, MUTED, RULE, axisWindow, fitDirectLabel, measureText, valueAxisTicks } from "./chartTheme.js";
	import { mobileNow, trackNarrow } from "./narrow.js";

	let narrow = mobileNow();
	let layoutTick = 0;
	onMount(() => trackNarrow((value) => {
		narrow = value;
		layoutTick += 1;
	}));

	export let labels = [];
	export let commit = [];
	export let bestCase = [];
	export let quota = 0;
	export let height = 280;

	$: finite = [...commit, ...bestCase, quota].filter((value) => Number.isFinite(value) && value != null);
	$: scale = axisWindow(Math.min(...finite), Math.max(...finite), { floor: 0.35 });
	$: axis = (() => {
		const ticks = scale.ticks || [];
		const step = ticks.length > 1 ? Math.abs(ticks[1] - ticks[0]) : 0;
		const half = step / 2;
		const kept = ticks.filter((tick, index) => {
			if (index === 0) return true;
			return half <= 0 || Math.abs(tick - Number(quota)) > half;
		});
		const baseline = kept[0];
		const labeled = kept.slice(1, 4);
		return { ...scale, ticks: baseline == null ? kept : [baseline, ...labeled] };
	})();
	$: last = Math.max(commit.length - 1, 0);

	function named(prefix, value) {
		const text = money(value);
		const full = `${prefix} ${text}`;
		return narrow ? fitDirectLabel(full, text, '600 12px "IBM Plex Sans", sans-serif') : full;
	}

	$: gutter = (() => {
		void layoutTick;
		if (!narrow) return 132;
		const labels = [named("Commit", commit[last]), named("Best case", bestCase[last])];
		const widest = Math.max(36, ...labels.map((text) => measureText(text, '600 12px "IBM Plex Sans", sans-serif')));
		return Math.ceil(widest + 16);
	})();

	$: option = {
		grid: { left: narrow ? 44 : 64, right: gutter, top: 28, bottom: 28 },
		xAxis: {
			type: "category",
			data: labels,
			axisLine: { lineStyle: { color: RULE } },
			axisTick: { show: false },
			axisLabel: {
				color: MUTED,
				fontFamily: "IBM Plex Sans Condensed, sans-serif",
				fontSize: 12,
				interval: narrow
					? (index) => index % Math.max(1, Math.ceil(labels.length / 4)) === 0 || index === labels.length - 1
					: 0,
			},
			splitLine: { show: false },
		},
		yAxis: valueAxisTicks(axis, (value) => axisMoney(value)),
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
								formatter: narrow
									? fitDirectLabel(`Quota ${money(quota)}`, money(quota), '400 12px "IBM Plex Sans", sans-serif')
									: `Quota ${money(quota)}`,
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
									text: named("Commit", commit[last]),
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
									text: named("Best case", bestCase[last]),
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
