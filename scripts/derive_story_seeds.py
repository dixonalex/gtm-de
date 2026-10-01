"""Write plan and quota seeds from warehouse actuals, and the match-decision seed.

Plan and quota numbers are actuals minus the scripted gaps in the story contract.
The script is the source of those CSVs. Do not hand-edit the generated files.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SEEDS = ROOT / "dbt" / "seeds"
DUCK = ROOT / "dbt" / "gtm.duckdb"
RAW = ROOT / "data" / "raw" / "salesforce" / "account.csv"
TRUTH = ROOT / "data" / "truth" / "account_duplicates.csv"
STORY = ROOT / "data" / "truth" / "story_ids.json"

SEGMENTS = ["Enterprise", "Mid-market", "SMB", "Startups", "Public sector"]
MONTHS = [
    dt.date(2026, 1, 31), dt.date(2026, 2, 28), dt.date(2026, 3, 31), dt.date(2026, 4, 30),
    dt.date(2026, 5, 31), dt.date(2026, 6, 30), dt.date(2026, 7, 31), dt.date(2026, 8, 31),
]
# gap = actual - plan, so plan = actual - gap
ARR_GAP = {
    dt.date(2026, 1, 31): -200_000,
    dt.date(2026, 2, 28): -600_000,
    dt.date(2026, 3, 31): -900_000,
    dt.date(2026, 4, 30): -1_400_000,
    dt.date(2026, 5, 31): -1_900_000,
    dt.date(2026, 6, 30): -2_100_000,
    dt.date(2026, 7, 31): -1_800_000,
    dt.date(2026, 8, 31): -2_400_000,
}
AUG = dt.date(2026, 8, 31)
AUG_ENTERPRISE_ARR_GAP = -1_100_000
NET_NEW_GAP = {
    "Enterprise": -400_000,
    "Mid-market": 100_000,
    "SMB": 0,
    "Startups": 0,
    "Public sector": -300_000,
}
# Jan–Jul bookings beat plan by these margins (actual / plan - 1). August is 89% of plan.
BOOKINGS_BEAT = {
    dt.date(2026, 1, 31): 0.04,
    dt.date(2026, 2, 28): 0.05,
    dt.date(2026, 3, 31): 0.06,
    dt.date(2026, 4, 30): 0.04,
    dt.date(2026, 5, 31): 0.07,
    dt.date(2026, 6, 30): 0.05,
    dt.date(2026, 7, 31): 0.03,
}
AUG_BOOKINGS_RATIO = 0.89
NRR_GAP = -0.005
GRR_GAP = -0.01
# Won is 81% of quota, the week-13 commit is 91%, best case is 97%.
WON_OF_QUOTA = 0.81
COMMIT_OF_QUOTA = 0.91
BEST_OF_QUOTA = 0.97
# Contract path in millions. The level is scaled onto the derived week-13 commit.
CALL_PATH = [13.2, 13.6, 13.9, 14.2, 14.5, 14.3, 14.1, 13.9, 13.8, 13.7, 13.6, 13.5, 13.4]
CALL_WEEKS = [
    dt.date(2026, 7, 6), dt.date(2026, 7, 13), dt.date(2026, 7, 20), dt.date(2026, 7, 27),
    dt.date(2026, 8, 3), dt.date(2026, 8, 10), dt.date(2026, 8, 17), dt.date(2026, 8, 24),
    dt.date(2026, 8, 31), dt.date(2026, 9, 7), dt.date(2026, 9, 14), dt.date(2026, 9, 21),
    dt.date(2026, 9, 28),
]
COMMIT = {
    "Enterprise": 6_100_000,
    "Mid-market": 3_900_000,
    "SMB": 1_300_000,
    "Startups": 900_000,
    "Public sector": 1_200_000,
}


def name_key(name: str) -> str:
    s = (name or "").lower()
    s = re.sub(r"\s*\([^)]*\)", "", s)
    s = s.replace(".", "")
    s = re.sub(r"[^a-z0-9]+", " ", s).strip()
    s = re.sub(r"(\s+(incorporated|holdings|group|corp|gmbh|llc|ltd|inc|kk|co))+$", "", s)
    s = re.sub(r"(\s+(international|worldwide|global|intl))+$", "", s).strip()
    return s


def domain_key(website: str) -> str:
    if not isinstance(website, str) or not website:
        return ""
    s = website.lower()
    s = re.sub(r"^https?://", "", s)
    s = re.sub(r"^www\.", "", s)
    return s.split("/")[0]


def damerau(a: str, b: str) -> int:
    if abs(len(a) - len(b)) > 1:
        return 2
    la, lb = len(a), len(b)
    d = [[0] * (lb + 1) for _ in range(la + 1)]
    for i in range(la + 1):
        d[i][0] = i
    for j in range(lb + 1):
        d[0][j] = j
    for i in range(1, la + 1):
        for j in range(1, lb + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
    return d[la][lb]


def write_decisions() -> None:
    accounts = pd.read_csv(RAW, dtype=str).fillna("")
    truth = pd.read_csv(TRUTH, dtype=str)
    master = dict(zip(truth.account_id, truth.true_master_account_id))
    story = json.loads(STORY.read_text()) if STORY.exists() else {"pending": [], "reject": []}
    pending = {frozenset(pair) for pair in story.get("pending", [])}
    reject = {frozenset(pair) for pair in story.get("reject", [])}
    rows = []
    recs = []
    for rec in accounts.itertuples(index=False):
        recs.append({
            "id": rec.Id,
            "key": name_key(rec.Name),
            "domain": domain_key(rec.Website),
            "currency": rec.CurrencyIsoCode,
            "parent": rec.ParentId,
        })
    for i, a in enumerate(recs):
        if not a["key"]:
            continue
        for b in recs[i + 1:]:
            if a["currency"] != b["currency"] or not b["key"]:
                continue
            if a["domain"] and a["domain"] == b["domain"]:
                continue
            if a["parent"] == b["id"] or b["parent"] == a["id"]:
                continue
            if damerau(a["key"], b["key"]) > 1:
                continue
            pair = frozenset((a["id"], b["id"]))
            left, right = sorted((a["id"], b["id"]))
            if pair in pending:
                continue
            if pair in reject:
                rows.append((left, right, "reject", "A. Dixon", "2026-09-28", "kept separate"))
            elif master.get(a["id"]) and master.get(a["id"]) == master.get(b["id"]):
                rows.append((left, right, "approve", "simulated_steward", "2026-09-15", "same company"))
            else:
                rows.append((left, right, "reject", "simulated_steward", "2026-09-15", "different companies"))
    path = SEEDS / "account_match_decisions.csv"
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["account_id_a", "account_id_b", "decision", "decided_by", "decided_at", "note"])
        w.writerows(rows)
    print(f"decisions {len(rows)}")


def _spread(gap: float, weights: dict[str, float]) -> dict[str, float]:
    total = sum(weights.values())
    if total <= 0:
        return {k: 0.0 for k in weights}
    return {k: gap * v / total for k, v in weights.items()}


def write_plans() -> None:
    con = duckdb.connect(str(DUCK), read_only=True)
    arr = con.execute(
        """
        select month_end, segment,
               sum(committed_arr_usd) as arr_usd,
               sum(arr_new_usd + arr_expansion_usd + arr_contraction_usd
                   + arr_churn_usd + arr_reactivation_usd) as net_new_usd
        from marts.fct_arr_monthly
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by 1, 2
        """
    ).fetchdf()
    bookings = con.execute(
        """
        select month_end, segment, sum(bookings_acv_usd) as bookings_usd
        from marts.fct_bookings_monthly
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by 1, 2
        """
    ).fetchdf()
    nrr = con.execute(
        """
        select nrr, grr from marts.fct_nrr_grr where month_end = date '2026-08-31'
        """
    ).fetchone()
    won = con.execute(
        """
        select coalesce(sum(bookings_acv_usd), 0)
        from marts.fct_bookings_monthly
        where month_end between date '2026-07-31' and date '2026-09-30'
        """
    ).fetchone()[0]
    con.close()

    nrr_plan = (nrr[0] - NRR_GAP) if nrr else 0
    grr_plan = (nrr[1] - GRR_GAP) if nrr else 0
    arr["month_end"] = pd.to_datetime(arr["month_end"]).dt.date
    bookings["month_end"] = pd.to_datetime(bookings["month_end"]).dt.date

    plan_rows = []
    for month in MONTHS:
        month_arr = arr[arr.month_end == month]
        month_book = bookings[bookings.month_end == month]
        actual_arr = {r.segment: float(r.arr_usd) for r in month_arr.itertuples()}
        actual_nn = {r.segment: float(r.net_new_usd) for r in month_arr.itertuples()}
        actual_bk = {r.segment: float(r.bookings_usd) for r in month_book.itertuples()}
        if month == AUG:
            arr_gap = _spread(
                ARR_GAP[month] - AUG_ENTERPRISE_ARR_GAP,
                {s: actual_arr.get(s, 0) for s in SEGMENTS if s != "Enterprise"},
            )
            arr_gap["Enterprise"] = AUG_ENTERPRISE_ARR_GAP
            nn_gap = dict(NET_NEW_GAP)
            # actual / plan = 0.89, and gap = actual - plan.
            bk_gap = {
                s: actual_bk.get(s, 0) * (1 - 1 / AUG_BOOKINGS_RATIO) for s in SEGMENTS
            }
        else:
            arr_gap = _spread(ARR_GAP[month], {s: actual_arr.get(s, 0) for s in SEGMENTS})
            nn_gap = {s: 0.0 for s in SEGMENTS}
            beat = BOOKINGS_BEAT[month]
            bk_gap = {s: actual_bk.get(s, 0) * beat / (1 + beat) for s in SEGMENTS}
        for segment in SEGMENTS:
            actual_a = actual_arr.get(segment, 0.0)
            actual_n = actual_nn.get(segment, 0.0)
            actual_b = actual_bk.get(segment, 0.0)
            plan_rows.append({
                "month_end": month.isoformat(),
                "segment": segment,
                "arr_usd": actual_a - arr_gap.get(segment, 0.0),
                "net_new_usd": actual_n - nn_gap.get(segment, 0.0),
                "bookings_usd": actual_b - bk_gap.get(segment, 0.0),
                "nrr_plan": nrr_plan,
                "grr_plan": grr_plan,
            })
    pd.DataFrame(plan_rows).to_csv(SEEDS / "plan_monthly.csv", index=False)

    commit_weight = sum(COMMIT.values())
    quota_total = float(won) / WON_OF_QUOTA
    commit_total = COMMIT_OF_QUOTA * quota_total
    # Commit shares keep the contract shape, then a small shift from Public sector
    # to Mid-market makes commit/quota land on 85/108/100/100/67 while the company
    # totals stay 81% won and 91% commit.
    targets = {
        "Enterprise": 0.85,
        "Mid-market": 1.08,
        "SMB": 1.00,
        "Startups": 1.00,
        "Public sector": 0.67,
    }
    shares = {segment: COMMIT[segment] / commit_weight for segment in COMMIT}
    need = 1 / COMMIT_OF_QUOTA
    low, high = 0.0, shares["Public sector"]
    for _ in range(60):
        mid = (low + high) / 2
        trial = dict(shares)
        trial["Public sector"] -= mid
        trial["Mid-market"] += mid
        if sum(trial[segment] / targets[segment] for segment in trial) > need:
            low = mid
        else:
            high = mid
    shares["Public sector"] -= low
    shares["Mid-market"] += low
    quota_rows = []
    for segment in COMMIT:
        commit_usd = commit_total * shares[segment]
        quota_rows.append({
            "quarter_start": "2026-07-01",
            "segment": segment,
            "quota_usd": commit_usd / targets[segment],
            "commit_usd": commit_usd,
        })
    pd.DataFrame(quota_rows).to_csv(SEEDS / "quota_quarterly.csv", index=False)

    scale = commit_total / (CALL_PATH[-1] * 1_000_000)
    best_per_commit = BEST_OF_QUOTA / COMMIT_OF_QUOTA
    call_rows = []
    for i, (week, millions) in enumerate(zip(CALL_WEEKS, CALL_PATH), start=1):
        commit = millions * 1_000_000 * scale
        call_rows.append({
            "week_start": week.isoformat(),
            "week_index": i,
            "commit_usd": round(commit, 2),
            "best_case_usd": round(commit * best_per_commit, 2),
        })
    pd.DataFrame(call_rows).to_csv(SEEDS / "forecast_call_weekly.csv", index=False)
    print(
        f"plans months={len(MONTHS)} won_qtd={won:.0f} quota_total={quota_total:.0f} "
        f"commit={commit_total:.0f}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["prepare", "plans"], required=True)
    args = parser.parse_args()
    if args.phase == "prepare":
        write_decisions()
    else:
        write_plans()


if __name__ == "__main__":
    main()
