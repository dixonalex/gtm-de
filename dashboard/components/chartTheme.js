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

/**
 * At most three labeled hairlines.
 * Default keeps ~15% padding and places ticks inside it.
 * `zero` pins the floor at 0. `cover` snaps both ends onto ticks so the
 * lowest gridline is at or below the data.
 */
export function axisWindow(dataMin, dataMax, { zero = false, pad = 0.15, cover = false } = {}) {
	const hi = Number(dataMax);
	const lo = zero ? Math.min(0, Number(dataMin)) : Number(dataMin);
	const span = Math.max(hi - lo, Math.abs(hi) * 0.02, 1);
	const floor = zero ? 0 : lo - span * pad;
	const cap = hi + span * pad;
	let best = null;
	for (const step of niceSteps(span)) {
		if (cover || zero) {
			const min = zero ? 0 : Math.floor(lo / step) * step;
			const max = Math.ceil((hi - step * 1e-8) / step) * step;
			if (!(max > min)) continue;
			const ticks = niceTicks(min, max, step);
			if (ticks.length < 2 || ticks.length > 3) continue;
			if (ticks[0] > lo + step * 1e-6 || ticks[ticks.length - 1] < hi - step * 1e-6) continue;
			const score = (ticks.length === 3 ? 2 : 0) - (max - min) / span;
			if (!best || score > best.score) best = { min, max, ticks, score };
		} else {
			const ticks = niceTicks(floor, cap, step).filter((tick) => tick > floor + step * 1e-6 && tick < cap - step * 1e-6);
			if (ticks.length < 2 || ticks.length > 3) continue;
			const score = (ticks.length === 3 ? 2 : 0) + (ticks[0] <= lo ? 1 : 0);
			if (!best || score > best.score) best = { min: floor, max: cap, ticks, score };
		}
	}
	if (!best) {
		const min = zero ? 0 : lo;
		const max = hi + span * pad;
		return { min, max, ticks: [min, (min + max) / 2, max] };
	}
	const min = best.min === 0 ? 0 : best.min;
	const max = best.max === 0 ? 0 : best.max;
	return { min, max, ticks: best.ticks };
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
