#!/usr/bin/env python3
"""Build the dashboard and assert the five pages show the contract numbers."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "dashboard" / "build"
NUMBERS = ROOT / "docs" / "design" / "screen_numbers.json"
MINUS = "\u2212"


def money(value: float, signed: bool = False) -> str:
    if abs(value) < 0.5:
        return "$0"
    negative = value < 0
    v = abs(value)
    if v >= 1_000_000:
        body = f"${v / 1_000_000:.1f}M"
    elif v >= 1_000:
        thousands = v / 1_000
        digits = 0 if thousands >= 10 else 1
        body = f"${thousands:.{digits}f}K"
    else:
        body = f"${round(v):,}"
    if negative:
        return f"{MINUS}{body}"
    if signed:
        return f"+{body}"
    return body


def percent(value: float) -> str:
    pct = value * 100 if abs(value) <= 2 else value
    rounded = round(pct)
    use = 0
    if abs(pct) > 1e-9 and rounded == 0:
        use = 1
    if abs(pct - 100) > 1e-6 and rounded == 100:
        use = 1
    text = f"{abs(pct):.{use}f}"
    if float(text) == 0:
        return "0%"
    return f"{MINUS if pct < 0 else ''}{text}%"


def require(html: str, needles: list[str], page: str) -> list[str]:
    missing = [needle for needle in needles if needle not in html]
    if missing:
        print(f"{page} is missing:", file=sys.stderr)
        for needle in missing:
            print(f"  {needle}", file=sys.stderr)
    return missing


def sliced_arr(numbers: dict) -> list[str]:
    """Load /?segment=Enterprise and require the Committed ARR tile to be the rollup.

    Evidence keeps the prerendered rows on the first input query, then runs DuckDB
    in the browser. Virtual time ends before that query, so this waits on the clock.
    """
    port = "8765"
    debug = "9223"
    expected = money(numbers["executive"]["enterprise_arr"])
    company = money(numbers["executive"]["august_bridge"]["closing"])
    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", port, "--bind", "127.0.0.1"],
        cwd=BUILD,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    browser = subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            f"--remote-debugging-port={debug}",
            "--window-size=1440,900",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    node = Path.home() / ".nvm/versions/node/v22.17.0/bin/node"
    script = r"""
const debugPort = process.argv[1];
const pageUrl = process.argv[2];
const expected = process.argv[3];
const company = process.argv[4];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let target;
for (let i = 0; i < 50 && !target; i++) {
  try {
    const opened = await fetch(`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(pageUrl)}`, { method: "PUT" });
    target = await opened.json();
  } catch {
    await sleep(100);
  }
}
if (!target?.webSocketDebuggerUrl) {
  console.log("NO_TARGET");
  process.exit(0);
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
let seq = 0;
const pending = new Map();
ws.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  const resolve = pending.get(message.id);
  if (resolve) {
    pending.delete(message.id);
    resolve(message);
  }
});
await new Promise((resolve) => ws.addEventListener("open", resolve, { once: true }));
function send(method, params = {}) {
  const id = ++seq;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params }));
  });
}
const expression = `document.querySelector('[data-kpi="Committed ARR"]')?.innerText || ""`;
let text = "";
for (let i = 0; i < 40; i++) {
  const result = await send("Runtime.evaluate", { expression, returnByValue: true });
  text = result.result?.result?.value || "";
  if (text.includes(expected) && !text.includes(company)) break;
  await sleep(500);
}
console.log(text.replaceAll("\n", " | "));
ws.close();
"""
    try:
        result = subprocess.run(
            [str(node), "--input-type=module", "-e", script, debug, f"http://127.0.0.1:{port}/?segment=Enterprise", expected, company],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    finally:
        browser.terminate()
        server.terminate()
        browser.wait(timeout=5)
        server.wait(timeout=5)
    text = result.stdout.strip()
    if result.returncode != 0 or expected not in text or company in text:
        print("sliced executive view failed", file=sys.stderr)
        print(f"  expected {expected} in the Committed ARR tile", file=sys.stderr)
        print(text or result.stderr[-500:], file=sys.stderr)
        return ["enterprise slice"]
    print(f"sliced view: Committed ARR {expected}")
    return []


def main() -> int:
    env = os.environ.copy()
    node = Path.home() / ".nvm/versions/node/v22.17.0/bin"
    if node.exists():
        env["PATH"] = str(node) + os.pathsep + env.get("PATH", "")
    subprocess.run(["npm", "run", "sources:strict"], cwd=ROOT / "dashboard", env=env, check=True)
    subprocess.run(
        ["npm", "run", "build:strict"],
        cwd=ROOT / "dashboard",
        env=env,
        check=True,
    )
    numbers = json.loads(NUMBERS.read_text())
    def read(path: Path) -> str:
        return (
            path.read_text()
            .replace("&amp;", "&")
            .replace("&#39;", "'")
            .replace("&quot;", '"')
        )

    pages = {
        "executive": read(BUILD / "index.html"),
        "sales": read(BUILD / "sales" / "index.html"),
        "deal_desk": read(BUILD / "deal-desk" / "index.html"),
        "finance": read(BUILD / "finance" / "index.html"),
        "data_health": read(BUILD / "data-health" / "index.html"),
    }
    ex = numbers["executive"]
    sales = numbers["sales"]
    desk = numbers["deal_desk"]
    fin = numbers["finance"]
    health = numbers["data_health"]
    missing: list[str] = []
    missing += require(
        pages["executive"],
        [
            money(ex["august_bridge"]["closing"]),
            money(ex["august_bridge"]["opening"]),
            money(ex["august_bridge"]["new"], signed=True),
            percent(ex["nrr"]),
            percent(ex["grr"]),
            "No commentary yet",
            "Committed ARR vs plan, FY26",
            "Revenue review",
            "EXECUTIVE · MONTHLY",
            "synced 12m ago",
            "Copy link to this view",
        ],
        "executive",
    )
    missing += require(
        pages["sales"],
        [
            money(sales["won_qtd"]),
            money(sales["quota"]),
            money(sales["week_13_commit"]),
            money(sales["week_13_best_case"]),
            *[row["account"] for row in sales["slipped_deals"]],
            "Forecast call by week vs quota",
            "Pipeline and forecast",
            "Commit vs quota by segment, Q3",
        ],
        "sales",
    )
    missing += require(
        pages["deal_desk"],
        [
            money(desk["open_amount"]),
            money(desk["past_sla_amount"]),
            money(desk["breach_tomorrow_amount"]),
            money(desk["resolved_amount"]),
            str(desk["open_count"]),
            str(desk["resolved_count"]),
            *[row["account"] for row in desk["open_items"]],
            "Quote-to-cash exceptions",
            "resolved past SLA",
        ],
        "deal desk",
    )
    missing += require(
        pages["finance"],
        [
            money(fin["bookings"]),
            money(fin["billings"]),
            money(fin["booked_not_billed"]),
            f"{round(fin['dso_days'])} days",
            *[row["account"] for row in fin["booked_not_billed_orders"]],
            "Bookings to billings",
        ],
        "finance",
    )
    missing += require(
        pages["data_health"],
        [
            *health.values(),
            "Sources and models",
            "Test-failure history is simulated.",
            "Pipeline and tests",
            "Last dbt build 16:52 UTC",
            "Next build 17:52 UTC · hourly",
        ],
        "data health",
    )
    missing += sliced_arr(numbers)
    if missing:
        print(f"page-check failed: {len(missing)} missing strings", file=sys.stderr)
        return 1
    print("page-check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
