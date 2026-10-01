const MINUS = "\u2212";

/** policy_thresholds: balance metrics 1%, flow metrics 5%, rates ±1 pt. */
export const BAND = { balance: 0.01, flow: 0.05 };
export const RATE_BAND_PTS = 1;

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function num(value) {
	if (value == null || value === "") return null;
	const n = typeof value === "number" ? value : Number(value);
	return Number.isFinite(n) ? n : null;
}

/** A query row has arrived. An empty object is the loading shell, not a zero result. */
export function present(row) {
	if (!row || typeof row !== "object") return false;
	return Object.values(row).some((value) => value != null && value !== "");
}

const LOCAL = { USD: "$", EUR: "€", GBP: "£", JPY: "¥", CAD: "C$", AUD: "A$" };

export function localMoney(currency, value) {
	const n = num(value);
	if (n == null || !currency || currency === "Total") return "";
	const symbol = LOCAL[currency] || "";
	const body = Math.round(Math.abs(n)).toLocaleString("en-US");
	return `${n < 0 ? MINUS : ""}${symbol}${body}`;
}

export function asRows(value) {
	if (!value) return [];
	if (Array.isArray(value)) return value;
	if (typeof value.length === "number") return Array.from(value);
	return [];
}

export function money(value, { signed = false } = {}) {
	const n = num(value);
	if (n == null) return "";
	if (Math.abs(n) < 0.5) return "$0";
	const negative = n < 0;
	const v = Math.abs(n);
	let body;
	if (v >= 1_000_000) {
		body = `$${(v / 1_000_000).toFixed(1)}M`;
	} else if (v >= 1_000) {
		const thousands = v / 1_000;
		const digits = thousands >= 10 ? 0 : 1;
		body = `$${thousands.toFixed(digits)}K`;
	} else {
		body = `$${Math.round(v).toLocaleString("en-US")}`;
	}
	if (negative) return `${MINUS}${body}`;
	if (signed) return `+${body}`;
	return body;
}

/** Hairline labels: $124M when the tick is a whole million, one decimal otherwise. */
export function axisMoney(value) {
	const n = num(value);
	if (n == null) return "";
	const abs = Math.abs(n);
	if (abs >= 1_000_000) {
		const millions = abs / 1_000_000;
		const digits = Math.abs(millions - Math.round(millions)) < 0.05 ? 0 : 1;
		const body = `$${millions.toFixed(digits)}M`;
		return n < 0 ? `${MINUS}${body}` : body;
	}
	return money(n);
}

export function percent(value, digits = 0) {
	const n = num(value);
	if (n == null) return "";
	const pct = Math.abs(n) <= 2 ? n * 100 : n;
	let use = digits;
	if (digits === 0) {
		const rounded = Math.round(pct);
		const hidesZero = Math.abs(pct) > 1e-9 && rounded === 0;
		const hidesHundred = Math.abs(pct - 100) > 1e-6 && rounded === 100;
		const hidesSign = pct < 0 && rounded === 0;
		const nearThreshold = Math.abs(pct) < 10 && Math.abs(pct - rounded) >= 0.25;
		if (hidesZero || hidesHundred || hidesSign || nearThreshold) use = 1;
	}
	const text = Math.abs(pct).toFixed(use);
	if (Number(text) === 0) return "0%";
	return `${pct < 0 ? MINUS : ""}${text}%`;
}

export function points(value) {
	const n = num(value);
	if (n == null) return "";
	if (Math.abs(n) < 0.05) return "0.0 pt";
	const sign = n < 0 ? MINUS : "+";
	return `${sign}${Math.abs(n).toFixed(1)} pt`;
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
	if (value == null || value === "") return null;
	if (typeof value === "number" && (!Number.isFinite(value) || value === 0)) return null;
	let parsed;
	if (value instanceof Date) {
		parsed = Number.isNaN(value.getTime()) ? null : value;
	} else {
		const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/);
		if (match) parsed = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
		else {
			const fallback = new Date(value);
			parsed = Number.isNaN(fallback.getTime()) ? null : fallback;
		}
	}
	// An unset date sometimes arrives as the epoch, which formats as 1 Jan.
	if (!parsed || parsed.getTime() === 0 || parsed.getUTCFullYear() < 2020) return null;
	return parsed;
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

export function ratePoints(actual, plan) {
	const a = num(actual);
	const p = num(plan);
	if (a == null || p == null) return null;
	const delta = a - p;
	return Math.abs(a) <= 2 && Math.abs(p) <= 2 ? delta * 100 : delta;
}

/** Inclusive points band from policy_thresholds.materiality_rate_pts. */
export function verdictRate(actual, plan, higherIsBetter = true) {
	const pts = ratePoints(actual, plan);
	if (pts == null) return { state: "missing", color: "var(--color-ink)" };
	if (Math.abs(pts) <= RATE_BAND_PTS + 1e-9) return { state: "inside", color: "var(--color-ink)" };
	const good = higherIsBetter ? pts > 0 : pts < 0;
	return {
		state: good ? "favorable" : "unfavorable",
		color: good ? "var(--color-favorable)" : "var(--color-unfavorable)",
	};
}

export function sameYearLabel(label) {
	return String(label ?? "").replace(/\s+20\d{2}\b/g, "").replace(/\s+/g, " ").trim();
}

export function onlyLabel(parts) {
	const names = parts.filter((value) => value && value !== "All");
	if (!names.length) return "";
	return `${names.join(" · ")} only`;
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
