#!/usr/bin/env python3
"""Build the dashboard and assert the five pages show the contract numbers."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "dashboard" / "build"
CONFIG = ROOT / "dashboard" / "evidence.config.yaml"
NUMBERS = ROOT / "docs" / "design" / "screen_numbers.json"
PAGES_BASE = "/gtm-de"
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


def chrome_executable() -> str:
    explicit = os.environ.get("CHROME_PATH")
    if explicit:
        return explicit
    mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if Path(mac).is_file():
        return mac
    for name in ("google-chrome", "chromium"):
        found = shutil.which(name)
        if found:
            return found
    sys.exit("chrome not found: set CHROME_PATH or install Google Chrome")


def node_executable() -> str:
    explicit = os.environ.get("NODE")
    if explicit:
        return explicit
    found = shutil.which("node")
    if not found:
        sys.exit("node not found: set NODE or install Node")
    return found


def headless_requested() -> bool:
    return "--headless" in sys.argv[1:] or bool(os.environ.get("CI"))


def live_pages(
    serve_root: Path,
    public_url: str,
    base_path: str = "",
    *,
    viewport: tuple[int, int] = (1440, 900),
    mobile: bool = False,
) -> list[str]:
    """Serve a static build and exercise every page in Chrome."""
    port = public_url.rsplit(":", 1)[-1].split("/", 1)[0]
    if mobile:
        debug = "9225"
    elif base_path:
        debug = "9224"
    else:
        debug = "9223"
    headless = headless_requested()
    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", port, "--bind", "127.0.0.1"],
        cwd=serve_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    chrome = chrome_executable()
    profile = Path("/tmp/gtm-page-check-chrome") / ("mobile" if mobile else base_path.strip("/") or "root")
    width, height = viewport
    command = [
        chrome,
        f"--user-data-dir={profile}",
        "--disable-gpu",
        "--no-first-run",
        f"--remote-debugging-port={debug}",
        f"--window-size={width},{height}",
    ]
    if headless:
        # GitHub-hosted runners start Chrome as root, which refuses the sandbox.
        command += ["--headless=new", "--no-sandbox"]
    command.append("about:blank")
    browser = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    node = node_executable()
    script = ROOT / "scripts" / "live_pages.mjs"
    argv = [str(node), str(script), debug, public_url, str(NUMBERS)]
    if base_path:
        argv.append(base_path)
    if mobile:
        argv.append("--mobile")
    try:
        result = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=180,
        )
    finally:
        browser.terminate()
        server.terminate()
        browser.wait(timeout=5)
        server.wait(timeout=5)
    label = ("mobile " if mobile else "") + (base_path or "/")
    if result.returncode != 0:
        print(f"live pages failed ({label})", file=sys.stderr)
        print((result.stderr or result.stdout)[-2000:], file=sys.stderr)
        return [f"live pages {label}"]
    print(result.stdout.strip())
    return []


def dashboard_build(env: dict, base_path: str | None) -> None:
    """Build the dashboard. A base path is written only for that build, per Evidence's deployment.basePath."""
    original = CONFIG.read_text()
    run_env = env.copy()
    if base_path:
        if "\ndeployment:" in f"\n{original}":
            sys.exit("evidence.config.yaml already sets deployment")
        suffix = "" if original.endswith("\n") else "\n"
        CONFIG.write_text(f"{original}{suffix}deployment:\n  basePath: {base_path}\n")
        # Evidence writes to ./build unless EVIDENCE_BUILD_DIR says otherwise.
        run_env["EVIDENCE_BUILD_DIR"] = f"./build{base_path}"
    try:
        subprocess.run(
            ["npm", "run", "build:strict"],
            cwd=ROOT / "dashboard",
            env=run_env,
            check=True,
        )
    finally:
        if base_path:
            CONFIG.write_text(original)


def main() -> int:
    env = os.environ.copy()
    node_dir = str(Path(node_executable()).resolve().parent)
    env["PATH"] = node_dir + os.pathsep + env.get("PATH", "")
    subprocess.run(["npm", "run", "sources:strict"], cwd=ROOT / "dashboard", env=env, check=True)
    numbers = json.loads(NUMBERS.read_text())

    def read(path: Path) -> str:
        return (
            path.read_text()
            .replace("&amp;", "&")
            .replace("&#39;", "'")
            .replace("&quot;", '"')
        )

    def load_pages(root: Path) -> dict[str, str]:
        return {
            "executive": read(root / "index.html"),
            "sales": read(root / "sales" / "index.html"),
            "deal_desk": read(root / "deal-desk" / "index.html"),
            "finance": read(root / "finance" / "index.html"),
            "data_health": read(root / "data-health" / "index.html"),
        }

    def static_pages(root: Path, base_path: str = "") -> list[str]:
        pages = load_pages(root)
        found: list[str] = []
        found += require(
            pages["executive"],
            [
                money(ex["august_bridge"]["closing"]),
                money(ex["august_bridge"]["opening"]),
                money(ex["august_bridge"]["new"], signed=True),
                percent(ex["nrr"]),
                percent(ex["grr"]),
                "No commentary for the company yet",
                "Committed ARR vs plan, FY26",
                "Revenue review",
                "EXECUTIVE · MONTHLY",
                "synced 12m ago",
                "Copy link to this view",
            ],
            "executive",
        )
        if base_path:
            found += require(
                pages["executive"],
                [
                    f'href="{base_path}/"',
                    f'href="{base_path}/sales/"',
                    f'href="{base_path}/deal-desk/"',
                    f'href="{base_path}/finance/"',
                    f'href="{base_path}/data-health/"',
                ],
                "base path",
            )
        company_call = next(row for row in sales["calls"] if row["segment"] == "All")
        found += require(
            pages["sales"],
            [
                money(sales["won_qtd"]),
                money(sales["quota"]),
                money(company_call["commit"]),
                money(company_call["best_case"]),
                *[row["account"] for row in sales["slipped_deals"]],
                "Forecast call by week vs quota",
                "Pipeline and forecast",
                "Commit vs quota by segment, Q3",
            ],
            "sales",
        )
        found += require(
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
                "Create order →",
                "Match invoice →",
                "Stop invoice →",
                "Approve reduction →",
                "Review lines →",
            ],
            "deal desk",
        )
        found += require(
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
        found += require(
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
        return found

    ex = numbers["executive"]
    sales = numbers["sales"]
    desk = numbers["deal_desk"]
    fin = numbers["finance"]
    health = numbers["data_health"]
    missing: list[str] = []
    dashboard_build(env, None)
    missing += static_pages(BUILD)
    missing += live_pages(BUILD, "http://127.0.0.1:8765")
    missing += live_pages(BUILD, "http://127.0.0.1:8767", viewport=(390, 844), mobile=True)
    dashboard_build(env, PAGES_BASE)
    pages_build = BUILD / PAGES_BASE.strip("/")
    missing += static_pages(pages_build, PAGES_BASE)
    missing += live_pages(BUILD, f"http://127.0.0.1:8766{PAGES_BASE}", PAGES_BASE)
    if missing:
        print(f"page-check failed: {len(missing)} missing strings", file=sys.stderr)
        return 1
    print("page-check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
