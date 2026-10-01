const MINUS = "\u2212";

/** policy_thresholds: balance metrics 1%, flow metrics 5%. */
export const BAND = { balance: 0.01, flow: 0.05 };

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function num(value) {
	const n = typeof value === "number" ? value : Number(value);
	return Number.isFinite(n) ? n : null;
}

function trim(n, digits) {
	return n.toFixed(digits).replace(/\.0+$/, "");
}

export function money(value, { signed = false } = {}) {
	const n = num(value);
	if (n == null) return "";
	if (Math.abs(n) < 0.5) return "$0";
	const negative = n < 0;
	const v = Math.abs(n);
	let body;
	if (v >= 1_000_000) {
		const millions = v / 1_000_000;
		const text = trim(millions, millions >= 100 ? 0 : 1);
		body = text === "0" ? null : `$${text}M`;
	} else if (v >= 1_000) {
		const thousands = v / 1_000;
		const digits = thousands >= 10 ? 0 : 1;
		const text = trim(thousands, digits);
		body = text === "0" ? null : `$${text}K`;
	} else {
		body = `$${Math.round(v).toLocaleString("en-US")}`;
	}
	if (!body) return "$0";
	if (negative) return `${MINUS}${body}`;
	if (signed) return `+${body}`;
	return body;
}

export function percent(value, digits) {
	const n = num(value);
	if (n == null) return "";
	const pct = Math.abs(n) <= 2 ? n * 100 : n;
	const d = digits ?? (Math.abs(pct - Math.round(pct)) < 0.05 ? 0 : 1);
	const text = trim(Math.abs(pct), d);
	if (Number(text) === 0) return "0%";
	return `${pct < 0 ? MINUS : ""}${text}%`;
}

export function points(value) {
	const n = num(value);
	if (n == null) return "";
	if (Math.abs(n) < 0.05) return "0 pt";
	const sign = n < 0 ? MINUS : "+";
	return `${sign}${trim(Math.abs(n), 1)} pt`;
}

export function days(value) {
	const n = num(value);
	if (n == null) return "";
	const d = Math.round(Math.abs(n));
	const sign = n < 0 ? MINUS : "";
	return `${sign}${d} ${d === 1 ? "day" : "days"}`;
}

export function count(value) {
	const n = num(value);
	if (n == null) return "";
	return Math.round(n).toLocaleString("en-US");
}

function parseDate(value) {
	if (value instanceof Date) return value;
	if (value == null || value === "") return null;
	const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/);
	if (match) return new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
	const parsed = new Date(value);
	return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function monthLabel(value) {
	const d = parseDate(value);
	if (!d) return "";
	return `${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

export function dayLabel(value) {
	const d = parseDate(value);
	if (!d) return "";
	return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

export function isoDate(value) {
	const d = parseDate(value);
	if (!d) return "";
	return d.toISOString().slice(0, 10);
}

export function gapRatio(actual, plan) {
	const a = num(actual);
	const p = num(plan);
	if (a == null || p == null || p === 0) return null;
	return (a - p) / Math.abs(p);
}

export function verdict(actual, plan, band = "balance", higherIsBetter = true) {
	const ratio = gapRatio(actual, plan);
	if (ratio == null) return { state: "missing", color: "var(--color-ink)" };
	const limit = BAND[band] ?? BAND.balance;
	if (Math.abs(ratio) <= limit) return { state: "inside", color: "var(--color-ink)" };
	const good = higherIsBetter ? ratio > 0 : ratio < 0;
	return {
		state: good ? "favorable" : "unfavorable",
		color: good ? "var(--color-favorable)" : "var(--color-unfavorable)",
	};
}

export function formatValue(value, format) {
	if (format === "percent") return percent(value);
	if (format === "days") return days(value);
	if (format === "count") return count(value);
	if (format === "points") return points(value);
	return money(value);
}

export function formatDelta(actual, plan, format) {
	if (plan == null || plan === "") return "No plan set";
	const delta = Number(actual) - Number(plan);
	if (format === "percent") {
		const pts = Math.abs(Number(actual)) <= 2 ? delta * 100 : delta;
		return `${points(pts)} vs plan`;
	}
	if (format === "days") {
		const sign = delta > 0 ? "+" : "";
		return `${sign}${days(delta)} vs plan`;
	}
	if (format === "count") {
		const n = Math.round(delta);
		const sign = n > 0 ? "+" : n < 0 ? MINUS : "";
		return `${sign}${Math.abs(n).toLocaleString("en-US")} vs plan`;
	}
	return `${money(delta, { signed: true })} vs plan`;
}
