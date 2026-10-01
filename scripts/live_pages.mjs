/**
 * Chrome checks against a static build.
 * argv: debugPort baseUrl numbersPath
 */
import { readFileSync } from "node:fs";

const debugPort = process.argv[2];
const base = process.argv[3];
const numbers = JSON.parse(readFileSync(process.argv[4], "utf8"));
const basePath = process.argv[5] || "";
const failures = [];
const bad = [];
const dataFetches = [];

function money(value) {
	const n = Math.abs(Number(value));
	if (n >= 1_000_000) return `$${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1_000) {
		const thousands = n / 1_000;
		return `$${thousands.toFixed(thousands >= 10 ? 0 : 1)}K`;
	}
	return `$${Math.round(n).toLocaleString("en-US")}`;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let seq = 0;
let ws;
const pending = new Map();

function send(method, params = {}) {
	const id = ++seq;
	return new Promise((resolve) => {
		pending.set(id, resolve);
		ws.send(JSON.stringify({ id, method, params }));
	});
}

async function connect(url) {
	let target;
	for (let i = 0; i < 50 && !target; i++) {
		try {
			const opened = await fetch(
				`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent("about:blank")}`,
				{ method: "PUT" },
			);
			target = await opened.json();
		} catch {
			await sleep(100);
		}
	}
	if (!target?.webSocketDebuggerUrl) throw new Error("NO_TARGET");
	ws = new WebSocket(target.webSocketDebuggerUrl);
	ws.addEventListener("message", (event) => {
		const message = JSON.parse(event.data);
		if (message.method === "Network.responseReceived") {
			const response = message.params?.response;
			if (response && response.status >= 400 && !response.url.endsWith("/favicon.ico")) {
				bad.push(`${response.status} ${response.url}`);
			}
			if (response && basePath && /\.(parquet|arrow)(\?|$)/i.test(response.url)) {
				dataFetches.push(response.url);
				const path = new URL(response.url).pathname;
				if (!path.startsWith(`${basePath}/`)) {
					failures.push(`fetch outside ${basePath}: ${response.url}`);
				}
			}
		}
		const resolve = pending.get(message.id);
		if (resolve) {
			pending.delete(message.id);
			resolve(message);
		}
	});
	await new Promise((resolve) => ws.addEventListener("open", resolve, { once: true }));
	await send("Network.enable");
	await send("Page.enable");
	await send("Page.navigate", { url });
}

function thrown(message) {
	const details = message?.result?.exceptionDetails;
	if (!details) return "";
	const text = details.exception?.description || details.text || details.exception?.value;
	return String(text || "evaluation failed").replaceAll("\n", " | ");
}

async function evaluate(expression, awaitPromise = false) {
	const message = await send("Runtime.evaluate", {
		expression,
		returnByValue: true,
		awaitPromise,
	});
	const error = thrown(message);
	if (error) throw new Error(error);
	return message.result?.result?.value ?? "";
}

async function evalText(expression) {
	const message = await send("Runtime.evaluate", { expression, returnByValue: true });
	return message.result?.result?.value ?? "";
}

async function assertNav(label) {
	if (!basePath) return;
	const raw = await evalText(
		`JSON.stringify([...document.querySelectorAll("a.gtm-tab, a.gtm-wordmark")].map((node) => node.getAttribute("href")))`,
	);
	let hrefs = [];
	try {
		hrefs = JSON.parse(raw || "[]");
	} catch {
		hrefs = [];
	}
	if (!hrefs.length) failures.push(`${label}: no nav links`);
	for (const href of hrefs) {
		if (href !== basePath && !String(href).startsWith(`${basePath}/`)) {
			failures.push(`${label} nav ${href}`);
		}
	}
}

async function assertCopy() {
	if (!basePath) return;
	const origin = new URL(base).origin;
	const prefix = `${origin}${basePath}/`;
	const before = failures.length;
	try {
		await waitFor(
			tile("Committed ARR"),
			(text) => text.includes(enterpriseArr) && !text.includes(companyArr),
			"copy link tiles",
		);
		await waitFor(
			`[...document.querySelectorAll("button")].some((node) => node.textContent.includes("Copy link to this view")) ? "ready" : ""`,
			(text) => text === "ready",
			"copy link button",
		);
		if (failures.length !== before) return;
		await evaluate(`(() => {
			window.__copied = "";
			Object.defineProperty(navigator, "clipboard", {
				configurable: true,
				value: { writeText: async (value) => { window.__copied = String(value); } },
			});
			document.execCommand = (command) => {
				if (command === "copy") {
					const node = document.activeElement;
					if (node && "value" in node) window.__copied = String(node.value);
				}
				return true;
			};
			return "ok";
		})()`);
		await evaluate(`(() => {
			const button = [...document.querySelectorAll("button")].find((node) => node.textContent.includes("Copy link to this view"));
			if (!button) throw new Error("copy button missing");
			button.click();
			return "clicked";
		})()`);
		let copied = "";
		const deadline = Date.now() + 3000;
		while (Date.now() < deadline) {
			copied = String(await evaluate("window.__copied || ''"));
			if (copied) break;
			await sleep(100);
		}
		const search = String(await evaluate("location.search"));
		let copiedSearch = "";
		try {
			copiedSearch = copied ? new URL(copied).search : "";
		} catch (error) {
			failures.push(`copy link: ${error?.message || copied || "not a url"}`);
			return;
		}
		if (!copied.startsWith(prefix) || copiedSearch !== search) {
			failures.push(`copy link: ${copied || "timed out before a URL was copied"}`);
		}
	} catch (error) {
		failures.push(`copy link: ${error?.message || error || "evaluation failed"}`);
	}
}

function tileFlash(text) {
	return /(?:^|[^\d$.])\$0(?![\d.])/.test(text) || /(?:^|[^\d.])0%(?!\d)/.test(text);
}

async function navigateWatch(url, expression, predicate, label) {
	const problems = [];
	const frames = [];
	const target = new URL(url);
	await send("Page.navigate", { url });
	let settled = "";
	let settledTiles = {};
	const deadline = Date.now() + 12000;
	while (Date.now() < deadline) {
		const raw = await evalText(`(() => JSON.stringify({
			path: location.pathname,
			search: location.search,
			tiles: Object.fromEntries([...document.querySelectorAll("[data-kpi]")].map((node) => [node.getAttribute("data-kpi") || "", node.innerText])),
		}))()`);
		let snap = {};
		try {
			snap = JSON.parse(raw || "{}");
		} catch {
			snap = {};
		}
		const path = (snap.path || "/").replace(/\/$/, "") || "/";
		const want = (target.pathname || "/").replace(/\/$/, "") || "/";
		if (path === want) {
			if (String(snap.search || "").includes("SELECT")) problems.push("url contains SELECT");
			frames.push(snap.tiles || {});
		}
		const probe = await evalText(expression);
		if (predicate(probe)) {
			settled = probe;
			settledTiles = snap.tiles || {};
			break;
		}
		await sleep(100);
	}
	// A loaded zero stays a zero. A placeholder is a zero that the settled tile replaces.
	for (const tiles of frames) {
		for (const [name, text] of Object.entries(tiles)) {
			if (!tileFlash(String(text || ""))) continue;
			if (tileFlash(String(settledTiles[name] || ""))) continue;
			problems.push(`tile ${name}`);
			break;
		}
	}
	if (!settled) failures.push(`${label}: did not settle`);
	else if (!predicate(settled)) failures.push(`${label}: ${String(settled).replaceAll("\n", " | ").slice(0, 240)}`);
	if (problems.length) failures.push(`${label} flash: ${[...new Set(problems)].slice(0, 3).join(" || ")}`);
	if (settled) await assertNav(label);
	return settled;
}

async function waitFor(expression, predicate, label) {
	let value = "";
	for (let i = 0; i < 40; i++) {
		value = await evalText(expression);
		if (predicate(value)) return value;
		await sleep(500);
	}
	failures.push(`${label}: ${String(value).replaceAll("\n", " | ").slice(0, 240)}`);
	return value;
}

async function clickOption(buttonIndex, optionText) {
	await evalText(`document.querySelectorAll('.slice-controls [data-button-root]')[${buttonIndex}]?.click()`);
	await sleep(400);
	const clicked = await evalText(`
		(() => {
			const item = [...document.querySelectorAll('[data-cmdk-item]')]
				.find((node) => node.textContent.trim() === ${JSON.stringify(optionText)});
			if (!item) return 'missing';
			item.click();
			return 'ok';
		})()
	`);
	if (clicked !== "ok") failures.push(`could not choose ${optionText}: ${clicked}`);
}

const tile = (label) =>
	`document.querySelector('[data-kpi="${label}"]')?.innerText || ''`;
const bullet = (label) =>
	`[...document.querySelectorAll('.bullet')].find((node) => node.innerText.startsWith(${JSON.stringify(label)}))?.innerText || ''`;

const companyArr = money(numbers.executive.august_bridge.closing);
const enterpriseArr = money(numbers.executive.enterprise_arr);
const mid = numbers.executive.slices.find((row) => row.segment === "Mid-market" && row.region === "All");
const midArr = money(mid.committed_arr);
const enterpriseWon = money(
	numbers.sales.calls.find((row) => row.segment === "Enterprise").won,
);
const companyWon = money(numbers.sales.won_qtd);
const owner = numbers.deal_desk.open_items[0].owner;
const companyBookings = money(numbers.finance.bookings);

try {
	await connect("about:blank");
	await navigateWatch(`${base}/`, tile("Committed ARR"), (text) => text.includes(companyArr), "default executive ARR");
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Company") && text.includes("Revenue review"),
		"default executive copy",
	);

	await navigateWatch(
		`${base}/?segment=Enterprise`,
		tile("Committed ARR"),
		(text) => text.includes(enterpriseArr) && !text.includes(companyArr),
		"seeded enterprise ARR",
	);
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Enterprise only"),
		"seeded enterprise subtitle",
	);
	await assertCopy();

	await clickOption(1, "Mid-market");
	await waitFor(
		`location.search`,
		(text) => text.includes("segment=Mid-market"),
		"executive URL after Mid-market",
	);
	await waitFor(
		tile("Committed ARR"),
		(text) => text.includes(midArr) && !text.includes(enterpriseArr),
		"Mid-market ARR",
	);

	await navigateWatch(`${base}/sales/`, bullet("Won QTD"), (text) => text.includes(companyWon), "default sales won");
	await navigateWatch(`${base}/sales/?segment=Enterprise`, `document.body.innerText`, (text) => text.includes("Enterprise only"), "seeded sales subtitle");
	await waitFor(
		bullet("Won QTD"),
		(text) => text.includes(enterpriseWon) && !text.includes(companyWon),
		"seeded sales won",
	);
	await clickOption(1, "Mid-market");
	await waitFor(
		`location.search`,
		(text) => text.includes("segment=Mid-market"),
		"sales URL after Mid-market",
	);

	await navigateWatch(
		`${base}/deal-desk/`,
		`document.body.innerText`,
		(text) => text.includes("Quote-to-cash exceptions") && text.includes("Create order"),
		"default deal desk",
	);
	const ownerUrl = `${base}/deal-desk/?owner=${encodeURIComponent(owner)}`;
	await navigateWatch(ownerUrl, `document.body.innerText`, (text) => text.includes(`${owner} only`), "seeded deal desk owner");
	await clickOption(2, "Won, no order");
	await waitFor(
		`location.search`,
		(text) => text.includes("type=won_without_order"),
		"deal desk URL after type",
	);

	await navigateWatch(`${base}/finance/`, tile("Bookings"), (text) => text.includes(companyBookings), "default finance bookings");
	await navigateWatch(`${base}/finance/?currency=EUR`, `document.body.innerText`, (text) => text.includes("EUR only"), "seeded finance currency");
	await waitFor(
		tile("Bookings"),
		(text) => text.length > 0 && !text.includes(companyBookings),
		"seeded finance bookings",
	);
	await clickOption(2, "Enterprise");
	await waitFor(
		`location.search`,
		(text) => text.includes("segment=Enterprise") && text.includes("currency=EUR"),
		"finance URL after segment",
	);

	await navigateWatch(
		`${base}/data-health/`,
		`document.body.innerText`,
		(text) => text.includes("Pipeline and tests") && text.includes("salesforce"),
		"default data health",
	);
	await navigateWatch(
		`${base}/data-health/?severity=ERROR`,
		`[...document.querySelectorAll('#lineage tbody .sr')].map((node) => node.textContent.trim()).join(',')`,
		(text) => text.length > 0 && text.split(",").every((part) => part === "ERROR"),
		"seeded data health severity",
	);
	await clickOption(2, "Warn");
	await waitFor(
		`location.search`,
		(text) => text.includes("severity=WARN"),
		"data health URL after Warn",
	);
} catch (error) {
	failures.push(String(error?.stack || error));
}

if (basePath && !dataFetches.length) failures.push(`no parquet or arrow fetches under ${basePath}`);
if (bad.length) failures.push(`http ${[...new Set(bad)].slice(0, 8).join(" | ")}`);
if (failures.length) {
	console.error(failures.join("\n"));
	process.exit(1);
}
console.log("live pages passed");
ws?.close();
