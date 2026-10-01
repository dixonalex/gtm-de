/**
 * Headed Chrome checks against a static build.
 * argv: debugPort baseUrl numbersPath
 */
import { readFileSync } from "node:fs";

const debugPort = process.argv[2];
const base = process.argv[3];
const numbers = JSON.parse(readFileSync(process.argv[4], "utf8"));
const failures = [];
const bad = [];

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

async function evalText(expression) {
	const result = await send("Runtime.evaluate", { expression, returnByValue: true });
	return result.result?.result?.value ?? "";
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
	await connect(`${base}/`);
	await waitFor(tile("Committed ARR"), (text) => text.includes(companyArr), "default executive ARR");
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Company") && text.includes("Revenue review"),
		"default executive copy",
	);

	await send("Page.navigate", { url: `${base}/?segment=Enterprise` });
	await waitFor(
		tile("Committed ARR"),
		(text) => text.includes(enterpriseArr) && !text.includes(companyArr),
		"seeded enterprise ARR",
	);
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Enterprise only"),
		"seeded enterprise subtitle",
	);

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

	await send("Page.navigate", { url: `${base}/sales/` });
	await waitFor(bullet("Won QTD"), (text) => text.includes(companyWon), "default sales won");
	await send("Page.navigate", { url: `${base}/sales/?segment=Enterprise` });
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Enterprise only"),
		"seeded sales subtitle",
	);
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

	await send("Page.navigate", { url: `${base}/deal-desk/` });
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Quote-to-cash exceptions") && text.includes("Create order"),
		"default deal desk",
	);
	const ownerUrl = `${base}/deal-desk/?owner=${encodeURIComponent(owner)}`;
	await send("Page.navigate", { url: ownerUrl });
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes(`${owner} only`),
		"seeded deal desk owner",
	);
	await clickOption(2, "Won, no order");
	await waitFor(
		`location.search`,
		(text) => text.includes("type=won_without_order"),
		"deal desk URL after type",
	);

	await send("Page.navigate", { url: `${base}/finance/` });
	await waitFor(tile("Bookings"), (text) => text.includes(companyBookings), "default finance bookings");
	await send("Page.navigate", { url: `${base}/finance/?currency=EUR` });
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("EUR only"),
		"seeded finance currency",
	);
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

	await send("Page.navigate", { url: `${base}/data-health/` });
	await waitFor(
		`document.body.innerText`,
		(text) => text.includes("Pipeline and tests") && text.includes("salesforce"),
		"default data health",
	);
	await send("Page.navigate", { url: `${base}/data-health/?severity=ERROR` });
	await waitFor(
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

if (bad.length) failures.push(`http ${[...new Set(bad)].slice(0, 8).join(" | ")}`);
if (failures.length) {
	console.error(failures.join("\n"));
	process.exit(1);
}
console.log("live pages passed");
ws?.close();
