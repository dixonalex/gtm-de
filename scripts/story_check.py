"""Prove the warehouse matches the story contract, and write the screen numbers."""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DUCK = ROOT / "dbt" / "gtm.duckdb"
OUT = ROOT / "docs" / "design" / "screen_numbers.json"

failures: list[str] = []
screens: dict = {}


def check(name: str, ok: bool, detail: str) -> None:
    mark = "ok" if ok else "FAIL"
    print(f"  {mark}  {name}: {detail}")
    if not ok:
        failures.append(f"{name}: {detail}")


def close(actual: float, target: float, tol: float = 0.10) -> bool:
    if target == 0:
        return abs(actual) < 50_000
    return abs(actual - target) / abs(target) <= tol


def tier2(name: str, actual: float, target: float, unit: str = "") -> None:
    pct = 0 if target == 0 else (actual / target - 1) * 100
    ok = close(actual, target)
    check(f"T2 {name}", ok, f"{actual:,.2f} vs {target:,.2f} {unit} ({pct:+.1f}%)")


def main() -> None:
    con = duckdb.connect(str(DUCK), read_only=True)
    print("Tier 1")

    fresh = {r[0]: r for r in con.execute(
        "select connector_id, age_minutes, age_hours, status from dq.dq_connector_freshness"
    ).fetchall()}
    sf, st = fresh["salesforce"], fresh["stripe"]
    check("salesforce freshness", sf[1] == 12 and sf[3] == "PASS", f"{sf[1]} min {sf[3]}")
    check("stripe freshness", st[2] == 31 and st[3] == "WARN", f"{st[2]} h {st[3]}")

    tests = con.execute(
        """
        select status, severity, count(*), coalesce(sum(failures), 0)
        from dq.dq_test_results
        where status in ('warn', 'fail', 'error')
        group by 1, 2
        order by 1, 2
        """
    ).fetchall()
    warns = sum(r[2] for r in tests if r[0] == "warn")
    errors = [r for r in tests if r[0] in ("fail", "error") and r[1] == "error"]
    error_n = sum(r[2] for r in errors)
    jpy = con.execute(
        """
        select failures from dq.dq_test_results
        where name = 'jpy_tie_out' and status in ('fail', 'error')
        """
    ).fetchone()
    check("one warn", warns == 1, f"{warns} warn rows, tests={tests}")
    check("one error", error_n == 1 and jpy and jpy[0] == 3, f"errors={error_n} jpy_rows={jpy}")

    latest = con.execute("select max(month_end) from marts.fct_arr_monthly").fetchone()[0]
    check("latest closed month", str(latest) == "2026-08-31", str(latest))

    # ARR gaps are exact because the plan was derived from these actuals.
    gaps = con.execute(
        """
        select month_end, sum(arr_gap_usd)
        from marts.fct_arr_plan
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by 1 order by 1
        """
    ).fetchall()
    expected_gaps = [-200_000, -600_000, -900_000, -1_400_000, -1_900_000, -2_100_000, -1_800_000, -2_400_000]
    for (month, gap), exp in zip(gaps, expected_gaps):
        check(f"ARR gap {month}", abs(gap - exp) < 1, f"{gap:.2f} vs {exp:.0f}")

    ent_gap = con.execute(
        """
        select arr_gap_usd from marts.fct_arr_plan
        where month_end = date '2026-08-31' and segment = 'Enterprise'
        """
    ).fetchone()[0]
    check("Enterprise ARR gap", abs(ent_gap - -1_100_000) < 1, f"{ent_gap:.2f}")

    nn = dict(con.execute(
        """
        select segment, net_new_gap_usd from marts.fct_arr_plan
        where month_end = date '2026-08-31'
        """
    ).fetchall())
    for segment, exp in {
        "Enterprise": -400_000, "Mid-market": 100_000, "SMB": 0,
        "Startups": 0, "Public sector": -300_000,
    }.items():
        check(f"net new gap {segment}", abs(nn[segment] - exp) < 1, f"{nn[segment]:.2f}")

    rates = con.execute(
        """
        select a.nrr, p.nrr_plan, a.grr, p.grr_plan
        from marts.fct_nrr_grr a
        join (select distinct nrr_plan, grr_plan from marts.fct_arr_plan
              where month_end = date '2026-08-31') p on true
        where a.month_end = date '2026-08-31'
        """
    ).fetchone()
    check("NRR gap", abs((rates[0] - rates[1]) - -0.005) < 1e-9, f"{rates[0]:.4f} vs plan {rates[1]:.4f}")
    check("GRR gap", abs((rates[2] - rates[3]) - -0.01) < 1e-9, f"{rates[2]:.4f} vs plan {rates[3]:.4f}")

    path = con.execute(
        """
        select month_end, nrr, grr
        from marts.fct_nrr_grr
        where month_end between date '2026-01-31' and date '2026-08-31'
        order by month_end
        """
    ).fetchall()
    check("NRR and GRR months", len(path) == 8, f"{len(path)} month-ends")
    for prev, cur in zip(path, path[1:]):
        nrr_pts = abs(cur[1] - prev[1]) * 100
        grr_pts = abs(cur[2] - prev[2]) * 100
        label = f"{prev[0]} → {cur[0]}"
        check(f"NRR moves gradually {label}", nrr_pts <= 1.5, f"{nrr_pts:.2f} pt")
        check(f"GRR moves gradually {label}", grr_pts <= 1.5, f"{grr_pts:.2f} pt")

    slice_path = con.execute(
        """
        select segment, region, month_end, nrr, grr
        from marts.rpt_executive_month
        where month_end between date '2026-01-31' and date '2026-08-31'
          and (segment = 'All' or region = 'All')
        order by segment, region, month_end
        """
    ).fetchall()
    by_slice = {}
    for segment, region, month_end, nrr, grr in slice_path:
        by_slice.setdefault((segment, region), []).append((month_end, nrr, grr))
    for (segment, region), points in by_slice.items():
        if segment == "All" and region == "All":
            continue
        label = f"{segment} / {region}"
        for prev, cur in zip(points, points[1:]):
            nrr_pts = abs(cur[1] - prev[1]) * 100
            grr_pts = abs(cur[2] - prev[2]) * 100
            when = f"{prev[0]} → {cur[0]}"
            check(f"slice NRR moves gradually {label} {when}", nrr_pts <= 1.5, f"{nrr_pts:.2f} pt")
            check(f"slice GRR moves gradually {label} {when}", grr_pts <= 1.5, f"{grr_pts:.2f} pt")

    won = con.execute(
        """
        select sum(bookings_acv_usd) from marts.fct_bookings_monthly
        where month_end between date '2026-07-31' and date '2026-09-30'
        """
    ).fetchone()[0]
    quota = con.execute("select sum(quota_usd), sum(commit_usd) from seeds.quota_quarterly").fetchone()
    check("won is 81% of quota", abs(won / quota[0] - 0.81) < 1e-6, f"won {won:.0f} quota {quota[0]:.0f}")
    check("commit is 91% of quota", abs(quota[1] / quota[0] - 0.91) < 1e-6, f"commit {quota[1]:.0f}")

    call = {r[0]: r for r in con.execute(
        "select week_index, commit_usd, best_case_usd from marts.fct_forecast_call"
    ).fetchall()}
    peak = max(r[1] for r in call.values())
    check("week 5 is the peak", abs(call[5][1] - peak) < 1, str(call[5][1]))
    check("week 13 commit", abs(call[13][1] - quota[1]) < 1, str(call[13][1]))
    check("best case is 97% of quota", abs(call[13][2] / quota[0] - 0.97) < 1e-6, str(call[13][2]))
    # The contract path slides 1.1 on a 13.4 week-13 call. The derived path keeps that shape.
    check(
        "commit slide shape",
        abs((call[5][1] - call[13][1]) / call[13][1] - (1.1 / 13.4)) < 1e-6,
        f"{call[5][1] - call[13][1]:,.0f}",
    )

    bridge = con.execute(
        """
        select
            sum(opening_arr_usd), sum(arr_new_usd), sum(arr_expansion_usd),
            sum(arr_contraction_usd), sum(arr_churn_usd), sum(arr_reactivation_usd),
            sum(committed_arr_usd)
        from marts.fct_arr_bridge where month_end = date '2026-08-31'
        """
    ).fetchone()
    tied = abs(bridge[0] + bridge[1] + bridge[2] + bridge[3] + bridge[4] + bridge[5] - bridge[6]) < 0.05
    check("ARR bridge ties", tied, f"close {bridge[6]:.2f}")

    bb = con.execute(
        """
        select bookings_usd, renewals_and_existing_usd, usage_overage_usd,
               booked_not_billed_usd, cancels_and_credits_usd, billed_without_order_usd, billings_usd
        from marts.fct_bookings_billings_bridge
        """
    ).fetchone()
    bb_tied = abs(bb[0] + bb[1] + bb[2] - bb[3] - bb[4] + bb[5] - bb[6]) < 0.05
    check("billings bridge ties", bb_tied, f"billings {bb[6]:.2f}")

    desk = con.execute(
        """
        select account_name, age_days, amount_usd, owner_name
        from marts.fct_deal_desk_exception where is_open
        """
    ).fetchall()
    desk_amt = sum(r[2] for r in desk)
    check("open queue", len(desk) == 10 and abs(desk_amt - 2_300_000) < 1, f"{len(desk)} ${desk_amt:,.0f}")
    today = con.execute(
        """
        select open_count, open_amount_usd, past_sla_count, past_sla_amount_usd,
               breach_tomorrow_count, breach_tomorrow_amount_usd
        from marts.fct_deal_desk_daily
        where snapshot_date = date '2026-09-30'
        """
    ).fetchone()
    yesterday = con.execute(
        """
        select open_count, open_amount_usd, past_sla_count, past_sla_amount_usd
        from marts.fct_deal_desk_daily
        where snapshot_date = date '2026-09-29'
        """
    ).fetchone()
    movement = con.execute(
        """
        select
            count(*) filter (where opened_on = date '2026-09-30'),
            coalesce(sum(amount_usd) filter (where opened_on = date '2026-09-30'), 0),
            count(*) filter (where resolved_on = date '2026-09-30'),
            coalesce(sum(amount_usd) filter (where resolved_on = date '2026-09-30'), 0)
        from marts.fct_deal_desk_exception
        """
    ).fetchone()
    check(
        "yesterday queue",
        yesterday[0] == 11 and abs(yesterday[1] - 2_390_000) < 1_000 and yesterday[2] == 2,
        f"{yesterday[0]} ${yesterday[1]:,.0f} past {yesterday[2]}",
    )
    check(
        "queue identity",
        today[0] == yesterday[0] + movement[0] - movement[2]
        and abs(today[1] - (yesterday[1] + movement[1] - movement[3])) < 1,
        f"today {today[0]} = {yesterday[0]} + {movement[0]} - {movement[2]}",
    )
    check("past SLA", today[2] == 3 and abs(today[3] - 726_000) < 1, f"{today[2]} ${today[3]:,.0f}")
    check("breach tomorrow", today[4] == 2 and abs(today[5] - 625_000) < 1, f"{today[4]} ${today[5]:,.0f}")
    resolved = con.execute(
        """
        select count(*), sum(amount_usd), median(age_days),
               count(*) filter (where past_sla)
        from marts.fct_deal_desk_exception
        where not is_open and resolved_on >= date '2026-09-23'
        """
    ).fetchone()
    check("resolved 7 days", resolved[0] == 23 and abs(resolved[1] - 4_800_000) < 1 and resolved[2] == 1.6 and resolved[3] == 2,
          f"{resolved[0]} ${resolved[1]:,.0f} median {resolved[2]} past {resolved[3]}")

    slips = con.execute(
        "select account_name, amount_usd, slip_count from marts.fct_slipped_deals"
    ).fetchall()
    check("slips", len(slips) == 6 and abs(sum(r[1] for r in slips) - 1_100_000) < 1,
          f"{len(slips)} ${sum(r[1] for r in slips):,.0f}")

    bnb = con.execute(
        """
        select account_name, amount_usd, age_bd from marts.fct_booked_not_billed
        where month_end = date '2026-08-31'
        """
    ).fetchall()
    check("booked not billed", len(bnb) == 5 and abs(sum(r[1] for r in bnb) - 1_800_000) < 1,
          f"{len(bnb)} ${sum(r[1] for r in bnb):,.0f}")
    bnb_jul = con.execute(
        """
        select coalesce(sum(amount_usd), 0)
        from marts.fct_booked_not_billed
        where month_end = date '2026-07-31'
        """
    ).fetchone()[0]
    check(
        "July booked not billed is a real balance",
        600_000 <= bnb_jul <= 1_500_000,
        f"${bnb_jul:,.0f}",
    )

    jpy = con.execute(
        """
        select sum(r.variance_usd)
        from marts.rpt_bookings_to_billings r
        join staging.stg_salesforce__account a on r.account_id = a.account_id
        where a.name like 'Yen Defect%'
        """
    ).fetchone()[0]
    check("JPY mismatch", abs(jpy - 100_000) < 100, f"${jpy:,.2f}")

    health = dict(con.execute(
        """
        select object_name, min(status) from marts.dq_model_health group by 1
        """
    ).fetchall())
    for name, expected in {
        "salesforce": "PASS", "stripe": "WARN", "fct_bookings": "PASS",
        "fct_billings": "WARN", "rpt_bookings_to_billings": "ERROR",
        "fct_arr_monthly": "PASS", "fct_pipeline_snapshot": "PASS",
    }.items():
        check(f"health {name}", health.get(name) == expected, f"{health.get(name)} vs {expected}")

    beats = {
        "2026-01-31": 0.04, "2026-02-28": 0.05, "2026-03-31": 0.06, "2026-04-30": 0.04,
        "2026-05-31": 0.07, "2026-06-30": 0.05, "2026-07-31": 0.03,
    }
    book_plan = con.execute(
        """
        select month_end, sum(bookings_acv_usd) as actual, sum(bookings_usd) as plan
        from marts.fct_bookings_monthly b
        join seeds.plan_monthly p using (month_end, segment)
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by 1 order by 1
        """
    ).fetchall()
    for month, actual, plan in book_plan:
        key = str(month)
        if key == "2026-08-31":
            check("Aug bookings are 89% of plan", abs(actual / plan - 0.89) < 1e-6, f"{actual / plan:.4f}")
        else:
            check(f"bookings beat {key}", abs(actual / plan - (1 + beats[key])) < 1e-6, f"{actual / plan:.4f}")

    print("Tier 2")
    aug = bridge
    tier2("Aug opening", aug[0], 124_600_000)
    tier2("Aug new", aug[1], 3_400_000)
    tier2("Aug expansion", aug[2], 1_600_000)
    tier2("Aug contraction", aug[3], -600_000)
    tier2("Aug churn", aug[4], -400_000)
    tier2("Aug reactivation", aug[5], 0)
    tier2("Aug closing", aug[6], 128_600_000)
    ent = con.execute(
        """
        select sum(committed_arr_usd) from marts.fct_arr_bridge
        where month_end = date '2026-08-31' and segment = 'Enterprise'
        """
    ).fetchone()[0]
    tier2("Enterprise share", ent / aug[6], 0.49)

    months = con.execute(
        """
        select month_end, sum(committed_arr_usd)
        from marts.fct_arr_monthly
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by 1 order by 1
        """
    ).fetchall()
    targets = [100.4, 103.5, 107.3, 110.8, 114.4, 119.0, 124.6, 128.6]
    for (month, actual), target in zip(months, targets):
        tier2(f"ARR {month}", actual, target * 1_000_000)

    print("Tier 3")
    check("NRR band", 1.02 <= rates[0] <= 1.06, f"{rates[0]:.4f}")
    check("GRR band", 0.88 <= rates[2] <= 0.92, f"{rates[2]:.4f}")

    slice_rates = con.execute(
        """
        select segment, region, nrr, grr, nrr_plan, grr_plan, committed_arr_usd
        from marts.rpt_executive_month
        where month_end = date '2026-08-31'
          and (segment = 'All' or region = 'All')
        order by segment, region
        """
    ).fetchall()
    for segment, region, nrr, grr, nrr_plan, grr_plan, _arr in slice_rates:
        if segment == "All" and region == "All":
            continue
        label = f"{segment} / {region}"
        check(f"slice NRR {label}", 0.98 <= nrr <= 1.12, f"{nrr:.4f}")
        check(f"slice GRR {label}", 0.85 <= grr <= 0.95, f"{grr:.4f}")
        check(
            f"slice NRR plan {label}",
            abs((nrr - nrr_plan) - -0.005) < 1e-8,
            f"{nrr:.4f} vs plan {nrr_plan:.4f}",
        )
        check(
            f"slice GRR plan {label}",
            abs((grr - grr_plan) - -0.01) < 1e-8,
            f"{grr:.4f} vs plan {grr_plan:.4f}",
        )
    forecast_order = con.execute(
        """
        select f.segment, f.team, f.rep, f.week_index, a.won_usd, f.commit_usd, f.best_case_usd
        from marts.rpt_sales_forecast f
        inner join marts.rpt_sales_attainment a using (segment, team, rep)
        where f.best_case_usd + 0.5 < f.commit_usd
           or (f.week_index = 13 and (a.won_usd > a.commit_usd + 0.5 or f.commit_usd + 0.5 < a.won_usd))
        """
    ).fetchall()
    check("won <= commit <= best case on every slice", not forecast_order, str(forecast_order[:4]))
    borrowed = con.execute(
        """
        select view_segment, view_region, label, note_segment, note_region
        from marts.rpt_executive_commentary
        where month_end = date '2026-08-31'
          and commentary is not null
          and (
            (not (view_segment = 'All' and view_region = 'All')
              and (note_segment != view_segment or note_region != view_region))
            or (view_segment = 'All' and view_region = 'All' and note_region != 'All')
            or (view_segment = 'All' and label like '%·%' and note_segment = 'All')
          )
        """
    ).fetchall()
    check("commentary text matches the row slice", not borrowed, str(borrowed[:4]))
    open_notes = con.execute(
        """
        select count(*)
        from marts.rpt_executive_commentary
        where month_end = date '2026-08-31'
          and commentary is null
          and (
            requested_on is distinct from date '2026-09-30'
            or due_on is distinct from date '2026-10-02'
            or requested_from is distinct from 'Sales leadership'
          )
        """
    ).fetchone()[0]
    check("placeholder commentary is requested 30 Sep and due 2 Oct", open_notes == 0, str(open_notes))

    # A loss and a same-size gain under one corporate parent are a planted pair.
    # Account-level amounts, so a parent rollup that happens to net to zero
    # still fails when the two legs match.
    paired = con.execute(
        """
        with moves as (
            select
                ultimate_parent_account_id as parent_id,
                month_end,
                master_account_id,
                abs(arr_contraction_usd + arr_churn_usd) as loss,
                arr_new_usd + arr_expansion_usd + arr_reactivation_usd as gain
            from marts.fct_arr_monthly
        )
        select count(*)
        from moves loss
        inner join moves gain
            on loss.parent_id = gain.parent_id
           and loss.month_end = gain.month_end
           and loss.master_account_id <> gain.master_account_id
        where loss.loss >= 1
          and gain.gain >= 1
          and abs(loss.loss - gain.gain) < 1
        """
    ).fetchone()[0]
    check("no paired loss and gain in one hierarchy", paired == 0, f"{paired} pairs")

    ar_rows = con.execute(
        """
        select month_end, current_usd, bucket_1_30_usd, bucket_31_90_usd, over_90_usd, ar_usd, dso_days
        from marts.fct_ar_aging
        where month_end between date '2026-01-31' and date '2026-08-31'
        order by 1
        """
    ).fetchall()
    ar_by = {r[0]: r for r in ar_rows}
    ar = ar_by[dt.date(2026, 8, 31)]
    mar = ar_by[dt.date(2026, 3, 31)]
    dso_months = [
        dt.date(2026, 3, 31), dt.date(2026, 4, 30), dt.date(2026, 5, 31),
        dt.date(2026, 6, 30), dt.date(2026, 7, 31), dt.date(2026, 8, 31),
    ]
    dso_vals = [ar_by[m][6] for m in dso_months]
    check("DSO rises Mar-Aug", all(b > a for a, b in zip(dso_vals, dso_vals[1:])), 
          ", ".join(f"{v:.1f}" for v in dso_vals))
    check("Aug DSO 45-50", 45 <= ar[6] <= 50, f"{ar[6]:.2f}")
    over_ratio = ar[4] / mar[4] if mar[4] else 0
    check("over-90 roughly doubles", 1.6 <= over_ratio <= 2.6, f"{over_ratio:.2f}x")
    check("Aug over-90 is 2-3% of AR", 0.02 <= ar[4] / ar[5] <= 0.03, f"{ar[4] / ar[5]:.3%}")
    current_ok = all(
        r[1] > r[2] and r[1] > r[3] and r[1] > r[4] for r in ar_rows
    )
    check("current is the largest bucket", current_ok, "Jan-Aug")

    center = aug[6] / 12 + bb[2]
    check(
        "Aug billings near ARR/12 + overage",
        abs(bb[6] - center) / center <= 0.25,
        f"billings {bb[6]:,.0f} vs {center:,.0f}",
    )
    unmatched = con.execute(
        """
        select sum(unmatched_usd) / nullif(sum(billed_usd), 0)
        from marts.fct_billings_by_currency
        """
    ).fetchone()[0]
    check("unmatched share above 1%", unmatched > 0.01, f"{unmatched:.3%}")

    usage_rows = con.execute(
        """
        select month_end, share_consumed, straight_line
        from marts.fct_commit_consumption
        order by 1
        """
    ).fetchall()
    for month_end, consumed, line in usage_rows:
        elapsed = (month_end - dt.date(2026, 1, 1)).days + 1
        check(
            f"straight line {month_end}",
            abs(line - elapsed / 365) < 1e-9,
            f"{line:.4f} vs {elapsed}/365",
        )
    gaps = [(r[0], r[2] - r[1]) for r in usage_rows]
    aug_gap = next(g for m, g in gaps if m == dt.date(2026, 8, 31))
    jan_gap = next(g for m, g in gaps if m == dt.date(2026, 1, 31))
    check("Aug commit gap 7-12 pts", 0.07 <= aug_gap <= 0.12, f"{aug_gap:.3f}")
    check("commit gap widens", aug_gap > jan_gap + 0.02, f"Jan {jan_gap:.3f} Aug {aug_gap:.3f}")
    check("commit gap outside 5 pts", aug_gap > 0.05, f"{aug_gap:.3f}")
    usage = con.execute(
        """
        select active_commits, commit_usd, share_consumed, straight_line
        from marts.fct_commit_consumption where month_end = date '2026-08-31'
        """
    ).fetchone()

    won_rate = con.execute(
        """
        select
            count(*) filter (where won_without_order)::double / nullif(count(*), 0)
        from staging.stg_salesforce__opportunity
        where is_won
          and close_date > date '2026-09-30' - interval 90 day
          and close_date <= date '2026-09-30'
        """
    ).fetchone()[0]
    check("won without order ~4%", 0.03 <= won_rate <= 0.05, f"{won_rate:.3%}")

    ratios = dict(con.execute(
        """
        select segment, commit_usd / quota_usd
        from seeds.quota_quarterly
        where quarter_start = date '2026-07-01'
        """
    ).fetchall())
    expected_ratios = {
        "Enterprise": 0.85, "Mid-market": 1.08, "SMB": 1.0,
        "Startups": 1.0, "Public sector": 0.67,
    }
    for segment, expected in expected_ratios.items():
        check(f"commit/quota {segment}", abs(ratios[segment] - expected) < 0.005, f"{ratios[segment]:.3f}")

    booking_months = [r[0] for r in con.execute(
        """
        select sum(bookings_acv_usd)
        from marts.fct_bookings_monthly
        where month_end between date '2026-01-31' and date '2026-08-31'
        group by month_end
        order by month_end
        """
    ).fetchall()]
    booking_mean = sum(booking_months) / len(booking_months)
    booking_band = all(0.50 * booking_mean <= value <= 1.75 * booking_mean for value in booking_months)
    check(
        "bookings months inside 50-175% of the mean",
        booking_band,
        ", ".join(f"{value / booking_mean:.0%}" for value in booking_months),
    )

    slip_dates = con.execute(
        """
        select previous_close_date, close_date
        from marts.fct_slipped_deals
        """
    ).fetchall()
    olds = {r[0] for r in slip_dates}
    news = {r[1] for r in slip_dates}
    check(
        "slip dates vary across late September and Q4",
        len(olds) >= 4 and len(news) >= 4
        and all(dt.date(2026, 9, 16) <= r[0] <= dt.date(2026, 9, 30) for r in slip_dates)
        and all(r[1] > dt.date(2026, 9, 30) for r in slip_dates),
        f"{len(olds)} prior, {len(news)} new",
    )

    unmatched_aug = con.execute(
        """
        select upper(i.currency), count(distinct b.invoice_id)
        from marts.fct_billings b
        inner join staging.stg_billing__invoice i on b.invoice_id = i.invoice_id
        where b.order_id is null
          and b.invoice_date between date '2026-08-01' and date '2026-08-31'
        group by 1
        order by 1
        """
    ).fetchall()
    unmatched_jul = con.execute(
        """
        select count(distinct invoice_id)
        from marts.fct_billings
        where order_id is null
          and invoice_date between date '2026-07-01' and date '2026-07-31'
        """
    ).fetchone()[0]
    status = dict(con.execute(
        "select currency, tie_out_status from marts.fct_billings_by_currency"
    ).fetchall())
    check(
        "August unmatched invoices are USD, EUR, and JPY",
        sorted(r[0] for r in unmatched_aug) == ["EUR", "JPY", "USD"] and all(r[1] == 1 for r in unmatched_aug),
        str(unmatched_aug),
    )
    check("July has one unmatched invoice", unmatched_jul == 1, str(unmatched_jul))
    check("USD unmatched is a warning", status.get("USD") == "warn", str(status))
    check("EUR unmatched is a warning", status.get("EUR") == "warn", str(status))
    check("JPY conversion is an error", status.get("JPY") == "error", str(status))

    booked_vs_kpi = con.execute(
        """
        select
            (select sum(booked_usd) from marts.fct_billings_by_currency),
            (select bookings_usd from marts.fct_bookings_billings_bridge)
        """
    ).fetchone()
    check(
        "currency booked sums to August bookings",
        abs(booked_vs_kpi[0] - booked_vs_kpi[1]) < 1,
        f"{booked_vs_kpi[0]:,.0f} vs {booked_vs_kpi[1]:,.0f}",
    )

    burn = con.execute(
        """
        select share_consumed, straight_line
        from marts.fct_commit_consumption
        order by month_end
        """
    ).fetchall()
    check(
        "commit burn is monotonic",
        all(b[0] + 1e-9 >= a[0] and b[1] + 1e-9 >= a[1] for a, b in zip(burn, burn[1:])),
        f"{len(burn)} months",
    )

    issues = con.execute(
        "select issue_type, age_days from marts.rpt_known_issues order by sort_order"
    ).fetchall()
    check(
        "backlog is the four known issue types",
        [r[0] for r in issues] == [
            "Invoices missing order metadata",
            "Duplicate account pairs pending review",
            "Late-arriving Salesforce rows",
            "Won without an order",
        ] and all(r[1] <= 30 for r in issues),
        str(issues),
    )

    families = con.execute(
        """
        select family, count(*), sum(failure_count)
        from marts.rpt_test_history
        group by family
        order by family
        """
    ).fetchall()
    by_family = {row[0]: row for row in families}
    check(
        "test history has four families on 30 days, uniqueness at zero",
        set(by_family) == {"freshness", "reconciliation", "relationships", "uniqueness"}
        and all(row[1] == 30 for row in families)
        and by_family["uniqueness"][2] == 0,
        str(families),
    )

    screens["executive"] = {
        "august_bridge": {
            "opening": aug[0], "new": aug[1], "expansion": aug[2],
            "contraction": aug[3], "churn": aug[4], "reactivation": aug[5], "closing": aug[6],
        },
        "arr_by_month": {str(m): v for m, v in months},
        "enterprise_arr": ent,
        "nrr": rates[0], "grr": rates[2],
        "won_qtd": won,
        "slices": [
            {
                "segment": segment, "region": region,
                "committed_arr": arr, "nrr": nrr, "grr": grr,
            }
            for segment, region, nrr, grr, _nrr_plan, _grr_plan, arr in slice_rates
        ],
    }
    screens["sales"] = {
        "won_qtd": won,
        "quota": quota[0],
        "commit": quota[1],
        "week_5_commit": call[5][1],
        "week_13_commit": call[13][1],
        "week_13_best_case": call[13][2],
        "slipped_amount": sum(r[1] for r in slips),
        "slipped_deals": [{"account": r[0], "amount": r[1], "slips": r[2]} for r in slips],
        "calls": [
            {"segment": segment, "won": won_usd, "commit": commit_usd, "best_case": best_usd}
            for segment, won_usd, commit_usd, best_usd in con.execute(
                """
                select a.segment, a.won_usd, a.commit_usd, f.best_case_usd
                from marts.rpt_sales_attainment a
                inner join marts.rpt_sales_forecast f using (segment, team, rep)
                where a.team = 'All' and a.rep = 'All' and f.week_index = 13
                order by a.segment
                """
            ).fetchall()
        ],
    }
    screens["deal_desk"] = {
        "open_count": today[0],
        "open_amount": today[1],
        "past_sla_count": today[2],
        "past_sla_amount": today[3],
        "breach_tomorrow_count": today[4],
        "breach_tomorrow_amount": today[5],
        "resolved_count": resolved[0],
        "resolved_amount": resolved[1],
        "resolved_median_days": resolved[2],
        "yesterday_open_count": yesterday[0],
        "yesterday_open_amount": yesterday[1],
        "yesterday_past_sla_count": yesterday[2],
        "open_items": [
            {"account": r[0], "age_days": r[1], "amount": r[2], "owner": r[3]} for r in desk
        ],
    }
    screens["finance"] = {
        "bookings": bb[0], "renewals_and_existing": bb[1], "usage_overage": bb[2],
        "booked_not_billed": bb[3], "cancels_and_credits": bb[4],
        "billed_without_order": bb[5], "billings": bb[6],
        "ar_current": ar[1], "ar_1_30": ar[2], "ar_31_90": ar[3], "ar_over_90": ar[4],
        "dso_days": ar[6],
        "active_commits": usage[0], "commit_usd": usage[1], "share_consumed": usage[2],
        "straight_line": usage[3],
        "booked_not_billed_orders": [
            {"account": r[0], "amount": r[1], "age_bd": r[2]} for r in bnb
        ],
    }
    screens["data_health"] = health
    OUT.write_text(json.dumps(screens, indent=2, default=str) + "\n")
    print(f"wrote {OUT}")
    if failures:
        print(f"\n{len(failures)} failed")
        raise SystemExit(1)
    print("\nstory-check passed")


if __name__ == "__main__":
    main()
