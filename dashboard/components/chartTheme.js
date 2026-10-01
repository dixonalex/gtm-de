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
			{ offset: 0.62, color: hex },
			{ offset: 1, color: `rgba(${r},${g},${b},0)` },
		],
	};
}
