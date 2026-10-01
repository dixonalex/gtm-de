export const INK = "#1B2126";
export const MUTED = "#5B646C";
export const CONTEXT = "#9AA1A8";
export const RULE = "#D9DCDF";
export const FOCUS = "#1F3A5F";
export const UNFAVORABLE = "#B23A32";
export const FAVORABLE = "#2F7D5B";

export const text = {
	fontFamily: "IBM Plex Sans, sans-serif",
	color: INK,
	fontSize: 12,
};

export const axis = {
	axisLine: { lineStyle: { color: RULE } },
	axisTick: { show: false },
	axisLabel: {
		color: MUTED,
		fontFamily: "IBM Plex Sans Condensed, sans-serif",
		fontSize: 12,
	},
	splitLine: { show: false },
};

export function valueAxis(formatter) {
	return {
		...axis,
		type: "value",
		splitNumber: 2,
		axisLine: { show: false },
		axisLabel: {
			...axis.axisLabel,
			formatter,
		},
		splitLine: {
			show: true,
			lineStyle: { color: RULE, width: 1 },
		},
	};
}

function niceSteps(span) {
	const rough = Math.max(span, 1e-9);
	const pow = 10 ** Math.floor(Math.log10(rough));
	const mults = [1, 2, 2.5, 5, 10];
	const steps = [];
	for (const scale of [0.1, 1, 10]) {
		for (const mult of mults) steps.push(mult * pow * scale);
	}
	return [...new Set(steps)].sort((a, b) => a - b);
}

function niceTicks(min, max, step) {
	if (!(step > 0) || !(max > min)) return [];
	const start = Math.ceil((min - step * 1e-8) / step) * step;
	const out = [];
	for (let value = start; value <= max + step * 1e-6 && out.length < 8; value += step) {
		const tick = Math.round(value / step) * step;
		if (tick >= min - step * 1e-6 && tick <= max + step * 1e-6) out.push(tick);
	}
	return out;
}

function finestTicks(min, max, limit) {
	const span = Math.max(max - min, 1);
	for (const step of niceSteps(span)) {
		const ticks = niceTicks(min, max, step).filter(
			(tick) => tick > min + step * 1e-6 && tick < max - step * 1e-6,
		);
		if (ticks.length >= 2 && ticks.length <= limit) return ticks;
	}
	return [];
}

/**
 * Labeled gridlines only: a baseline plus at most three hairlines.
 * `zero` pins the baseline at 0 and keeps the finest round step that fits
 * (an ARR book lands on $0 / $50M / $100M / $150M, not $200M).
 * `floor` is the fraction of the plot where the lowest value sits, used by
 * the truncated bridge so anchors have a body below the first hairline.
 */
export function axisWindow(dataMin, dataMax, { zero = false, floor = null } = {}) {
	const hi = Number(dataMax);
	const lo = Number(dataMin);
	if (floor != null && !zero) {
		const head = 0.1;
		const span = Math.max(hi - lo, Math.abs(hi) * 0.02, 1);
		const range = span / (1 - floor - head);
		const min = lo - floor * range;
		const max = min + range;
		return { min, max, ticks: finestTicks(min, max, 4) };
	}
	const base = zero ? Math.min(0, lo) : lo;
	const span = Math.max(hi - base, Math.abs(hi) * 0.02, 1);
	for (const step of niceSteps(span)) {
		const min = zero ? 0 : Math.floor((base + step * 1e-9) / step) * step;
		let max = Math.ceil((hi - step * 1e-9) / step) * step;
		if (!(max > min)) max = min + step;
		const ticks = niceTicks(min, max, step);
		if (
			ticks.length >= 2 &&
			ticks.length <= 4 &&
			ticks[0] <= base + step * 1e-6 &&
			ticks[ticks.length - 1] >= hi - step * 1e-6
		) {
			return { min: ticks[0] === 0 ? 0 : ticks[0], max: ticks[ticks.length - 1], ticks };
		}
	}
	const min = zero ? 0 : lo;
	const max = hi;
	return { min, max, ticks: [min, max] };
}

export function valueAxisTicks(window, formatter, { labels = true } = {}) {
	return {
		type: "value",
		min: window.min,
		max: window.max,
		axisLine: { show: false },
		axisTick: { show: false },
		axisLabel: {
			show: labels,
			customValues: window.ticks,
			color: MUTED,
			fontFamily: "IBM Plex Sans Condensed, sans-serif",
			fontSize: 12,
			formatter,
		},
		splitLine: {
			show: true,
			customValues: window.ticks,
			lineStyle: { color: RULE, width: 1 },
		},
	};
}

export function fade(hex) {
	const r = parseInt(hex.slice(1, 3), 16);
	const g = parseInt(hex.slice(3, 5), 16);
	const b = parseInt(hex.slice(5, 7), 16);
	return {
		type: "linear",
		x: 0,
		y: 0,
		x2: 0,
		y2: 1,
		colorStops: [
			{ offset: 0, color: hex },
			{ offset: 0.35, color: hex },
			{ offset: 1, color: `rgba(${r},${g},${b},0)` },
		],
	};
}
