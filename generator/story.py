"""Planted records for the story contract. Fixed ids, no calls into the simulation RNG."""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pandas as pd

from generate import DAY, add_months, minor, money, region_for, sf_suffix

ROOT = Path(__file__).resolve().parents[1]
AS_OF = dt.date(2026, 9, 30)
AUG_END = dt.date(2026, 8, 31)
NOW = dt.datetime(2026, 9, 30, 17, 5)


_ID_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"


def story_sfid(prefix: str, n: int) -> str:
    """18-char Salesforce id. The 15-char body is the key prefix plus 12
    mixed-case characters, then the real case-safe checksum. No STORY marker."""
    if len(prefix) != 3:
        raise AssertionError(prefix)
    salt = 0
    while salt < 64:
        x = (n * 0x9E3779B1 + 0x85EBCA6B + salt * 0x6C62272E) & 0xFFFFFFFF
        chars = []
        for i in range(12):
            x = (x * 1664525 + 1013904223 + i * 97) & 0xFFFFFFFF
            chars.append(_ID_ALPHABET[x % 62])
        body = prefix + "".join(chars)
        if len(body) == 15 and "STORY" not in body.upper():
            return body + sf_suffix(body)
        salt += 1
    raise AssertionError(f"no id for {prefix} {n}")


def reserved_account_names() -> set[str]:
    return {
        "Quarry Health", "Northwind Logistics", "Meridian Analytics", "Kestrel Bio",
        "Tidewater Health", "Larkspur Energy", "Harbor Health", "Alder Health",
    }


def _bd_before(end: dt.date, n: int) -> dt.date:
    """Date D such that weekdays in (D, end] number n."""
    d = end
    left = n
    while left > 0:
        d -= DAY
        if d.weekday() < 5:
            left -= 1
    return d


def _ts(d: dt.date, hour: int = 11) -> dt.datetime:
    return dt.datetime.combine(d, dt.time(hour, 0))


OWNERS = {
    "P. Nair": 1,
    "T. Wu": 2,
    "M. Okafor": 3,
    "J. Reyes": 4,
    "A. Chen": 5,
    "S. Ito": 6,
    "D. Brennan": 7,
    "L. Moreau": 8,
    "K. Adeyemi": 9,
}


def _owner(name: str) -> str:
    return story_sfid("005", OWNERS[name])


def _slug(name: str) -> str:
    return "".join(ch for ch in name.lower() if ch.isalnum())


def story_stripe_id(prefix: str, n: int) -> str:
    """Stripe-shaped id. Deterministic, and it does not consume the generator RNG."""
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    x = (n * 0x9E3779B1 + 0xC2B2AE35) & 0xFFFFFFFF
    chars = []
    for i in range(14):
        x = (x * 1664525 + 1013904223 + i * 97) & 0xFFFFFFFF
        chars.append(alphabet[x % 62])
    token = "".join(chars)
    if "story" in token.lower():
        token = token.replace("s", "z").replace("S", "Z")
    return prefix + token


def _add_users(g) -> None:
    created = dt.datetime(2024, 6, 3, 9, 0)
    for name, n in OWNERS.items():
        g.rows("user").append(dict(
            Id=_owner(name), Name=name, Title="Account Executive", IsActive=True,
            CreatedDate=created, SystemModstamp=created))


def _add_account(g, n, name, segment, country, currency, owner, employees=800):
    aid = story_sfid("001", n)
    created = dt.datetime(2024, 11, 4, 10, 0)
    website = f"{_slug(name)}.com"
    g.accounts.append(dict(
        Id=aid, Name=name, base=name, Website=website, Industry="Technology",
        NumberOfEmployees=employees, segment=segment, region=region_for(country),
        BillingCountry=country, BillingState="CA" if country == "US" else None,
        CurrencyIsoCode=currency, OwnerId=_owner(owner), CreatedDate=created,
        dup=None, canonical=aid, last_touch=created, won_any=True, active_contracts=1,
        case_type="story", ParentId=None, Type="Customer"))
    return g.accounts[-1]


def _line(g, acct, code, qty, unit, n):
    cur = acct["CurrencyIsoCode"]
    pbe, list_price = g.pbe[(code, cur)]
    total = money(qty * unit, cur)
    return dict(
        Id=story_sfid("802", n), code=code, qty=qty, unit=unit, list=list_price, pbe=pbe,
        total=total, Product2Id=g.products[code]["Id"])


def _add_opp(g, acct, n, close, amount, stage, won, lines, keep_open=False, slip_history=None):
    oid = story_sfid("006", n)
    cur = acct["CurrencyIsoCode"]
    created = _ts(close - dt.timedelta(days=40), 9)
    close_ts = _ts(close, 15)
    owner = acct["OwnerId"]
    history = slip_history or [(created.date(), stage[0], stage[1], stage[2], amount, close)]
    if won and not slip_history:
        history = [
            (created.date(), "Negotiation/Review", 80, "Commit", amount, close),
            (close, "Closed Won", 100, "Closed", amount, close),
        ]
    for i, (d, s, prob, fc, amt, cd) in enumerate(history):
        when = d.date() if isinstance(d, dt.datetime) else d
        t = _ts(when, 9 if i == 0 else 10 + i)
        g.rows("opportunity_history").append(dict(
            Id=story_sfid("008", n * 10 + i), OpportunityId=oid, StageName=s, Amount=amt,
            ExpectedRevenue=money(amt * prob / 100, cur), CloseDate=cd, Probability=prob,
            ForecastCategory=fc, CreatedById=owner, CreatedDate=t, SystemModstamp=t, IsDeleted=False))
    for ln in lines:
        g.rows("opportunity_line_item").append(dict(
            Id=story_sfid("00k", n * 10 + lines.index(ln)), OpportunityId=oid,
            PricebookEntryId=ln["pbe"], Product2Id=ln["Product2Id"], ProductCode=ln["code"],
            Quantity=ln["qty"], ListPrice=ln["list"], UnitPrice=ln["unit"], Discount=0,
            TotalPrice=ln["total"], ServiceDate=None, CurrencyIsoCode=cur,
            CreatedDate=created, SystemModstamp=close_ts, IsDeleted=False))
    opp = dict(
        Id=oid, AccountId=acct["Id"], Name=f"{acct['Name']} - Story", Type="New Business",
        StageName="Closed Won" if won else stage[0], Probability=100 if won else stage[1],
        ForecastCategoryName="Closed" if won else stage[2], Amount=amount, CloseDate=close,
        IsClosed=won, IsWon=won, LeadSource="Outbound", Won_Without_Order__c=keep_open,
        OwnerId=owner, CurrencyIsoCode=cur,
        Pricebook2Id=g.pricebook_id, SyncedQuoteId=None, HasOpportunityLineItem=bool(lines),
        CreatedDate=created, LastModifiedDate=close_ts, SystemModstamp=close_ts, IsDeleted=False,
        _keep_open=keep_open)
    g.rows("opportunity").append(opp)
    frozen = getattr(g, "_frozen_opps", None)
    if frozen is None:
        g._frozen_opps = set()
    g._frozen_opps.add(oid)
    return opp


def _add_order(g, acct, n, opp, start, end, lines, order_type, invoice_from=None, activated=True,
               cancel_on=None, reduction=False, original=None):
    cur = acct["CurrencyIsoCode"]
    oid = story_sfid("801", n)
    created = _ts(start, 11)
    items = []
    for ln in lines:
        recurring = g.products[ln["code"]]["recurring"]
        items.append(dict(
            Id=ln["Id"], OrderId=oid, Product2Id=ln["Product2Id"], PricebookEntryId=ln["pbe"],
            QuoteLineItemId=None, OriginalOrderItemId=None, Quantity=ln["qty"],
            ListPrice=ln["list"], UnitPrice=ln["unit"], TotalPrice=ln["total"],
            ServiceDate=start, EndDate=end if recurring else None, CurrencyIsoCode=cur,
            CreatedDate=created, SystemModstamp=created, IsDeleted=False, _code=ln["code"]))
    order = dict(
        Id=oid, OrderNumber=f"9{n:07d}", AccountId=acct["Id"],
        OpportunityId=opp["Id"] if opp else None, QuoteId=None,
        Pricebook2Id=g.pricebook_id, Type=order_type,
        Status="Activated" if activated else "Draft",
        StatusCode="Activated" if activated else "Draft",
        EffectiveDate=start, EndDate=end,
        ActivatedDate=created if activated else None,
        IsReductionOrder=reduction, OriginalOrderId=original, Billing_Frequency__c="Annual",
        TotalAmount=money(sum(x["TotalPrice"] for x in items), cur), CurrencyIsoCode=cur,
        CreatedDate=created, LastModifiedDate=created, SystemModstamp=created, IsDeleted=False,
        Cancelled_Date__c=cancel_on,
        _items=items, _acct=acct, _cancel=cancel_on, _reduction=None, _usage=[],
        _invoice_from=invoice_from, _jpy_scale_defect=False)
    if cancel_on:
        order.update(Status="Cancelled", StatusCode="Canceled")
    g.rows("order").append(order)
    g._protected_orders = getattr(g, "_protected_orders", set())
    g._protected_orders.add(oid)
    return order


def _usd_line(g, acct, n, amount, code="SEAT-ENT"):
    return _line(g, acct, code, 1, amount, n)


def _active_span(start, end=dt.date(2027, 7, 31)):
    return start, end


# Feb 2025 through Jul 2026. Early months are small because the cohort is
# small; later months grow with it so trailing-12-month GRR stays near 91%.
_LOSS_TARGETS = [
    43_000, 53_000, 64_000, 79_000, 96_000, 117_000, 143_000, 174_000,
    212_000, 258_000, 316_000, 385_000, 470_000, 573_000, 699_000, 854_000,
    1_042_000, 1_271_000,
]


def _loss_schedule():
    """Feb 2025–Jul 2026 cohort losses.

    Each month: a few full churns, several contractions at about 30% of that
    account's ARR, and expansions on other accounts that sum to the same
    dollars. Company stock is flat in the loss month. No loss amount equals
    a gain amount, and each account is its own hierarchy.
    """
    slots = []
    for i, target in enumerate(_LOSS_TARGETS):
        # Two churns carry about 60% of the month. Two contractions and two
        # expansions make up the rest, in distinct dollars, so a loss never
        # matches a gain.
        churn_pool = int(round(target * 0.6 / 1000) * 1000)
        churns = [int(round(churn_pool * 0.42 / 1000) * 1000)]
        churns.append(churn_pool - churns[0])
        cut_pool = target - sum(churns)
        cuts = [int(round(cut_pool * 0.45 / 1000) * 1000)]
        cuts.append(cut_pool - cuts[0])
        expansions = [int(round(target * 0.46 / 1000) * 1000)]
        expansions.append(target - expansions[0])
        # Nudge until every movement dollar is unique and positive.
        steps = 0
        while True:
            parts = churns + cuts + expansions
            if all(x > 0 for x in parts) and len(set(parts)) == len(parts) and sum(churns) + sum(cuts) == target and sum(expansions) == target:
                break
            churns[0] += 1_000
            churns[1] -= 1_000
            if churns[1] <= 0:
                cuts[0] += 1_000
                cuts[1] -= 1_000
                expansions[0] += 1_000
                expansions[1] -= 1_000
            steps += 1
            if steps > 80:
                raise AssertionError((i, target, churns, cuts, expansions))
        contractions = []
        for cut in cuts:
            before = int(round(cut / 0.32 / 1000.0) * 1000)
            if before - cut < 8_000:
                before = cut + 8_000
            contractions.append((before, before - cut))
        slots.append((churns, contractions, expansions))
    return slots


# Accounts that sit in the August trailing-12 cohort (loss month after Aug 2025).
# Segment and country are chosen so each segment and region lands in the rate
# band from its own churn, contraction, and expansion, without moving the
# company total. Earlier loss months stay on their original books.
_LOSS_PLACE = {
    (7, "churn", 0): ("SMB", "GB"),
    (7, "churn", 1): ("Public sector", "US"),
    (7, "cut", 0): ("SMB", "GB"),
    (7, "cut", 1): ("Mid-market", "GB"),
    (7, "exp", 0): ("Startups", "JP"),
    (7, "exp", 1): ("SMB", "GB"),
    (8, "churn", 0): ("Enterprise", "US"),
    (8, "churn", 1): ("Enterprise", "US"),
    (8, "cut", 0): ("Enterprise", "US"),
    (8, "cut", 1): ("Enterprise", "US"),
    (8, "exp", 0): ("SMB", "US"),
    (8, "exp", 1): ("Enterprise", "JP"),
    (9, "churn", 0): ("Enterprise", "US"),
    (9, "churn", 1): ("Enterprise", "US"),
    (9, "cut", 0): ("Enterprise", "US"),
    (9, "cut", 1): ("Enterprise", "US"),
    (9, "exp", 0): ("Mid-market", "US"),
    (9, "exp", 1): ("Mid-market", "US"),
    (10, "churn", 0): ("Enterprise", "US"),
    (10, "churn", 1): ("Enterprise", "US"),
    (10, "cut", 0): ("Enterprise", "US"),
    (10, "cut", 1): ("Enterprise", "GB"),
    (10, "exp", 0): ("Enterprise", "US"),
    (10, "exp", 1): ("Enterprise", "US"),
    (11, "churn", 0): ("Enterprise", "US"),
    (11, "churn", 1): ("Enterprise", "US"),
    (11, "cut", 0): ("Enterprise", "US"),
    (11, "cut", 1): ("Public sector", "US"),
    (11, "exp", 0): ("Enterprise", "US"),
    (11, "exp", 1): ("Enterprise", "US"),
    (12, "churn", 0): ("Enterprise", "US"),
    (12, "churn", 1): ("Enterprise", "US"),
    (12, "cut", 0): ("Mid-market", "US"),
    (12, "cut", 1): ("Mid-market", "US"),
    (12, "exp", 0): ("Enterprise", "US"),
    (12, "exp", 1): ("Enterprise", "US"),
    (13, "churn", 0): ("Enterprise", "US"),
    (13, "churn", 1): ("Enterprise", "US"),
    (13, "cut", 0): ("Enterprise", "US"),
    (13, "cut", 1): ("Enterprise", "US"),
    (13, "exp", 0): ("Enterprise", "US"),
    (13, "exp", 1): ("Enterprise", "US"),
    (14, "churn", 0): ("Enterprise", "US"),
    (14, "churn", 1): ("Enterprise", "US"),
    (14, "cut", 0): ("Enterprise", "US"),
    (14, "cut", 1): ("Enterprise", "US"),
    (14, "exp", 0): ("Enterprise", "US"),
    (14, "exp", 1): ("Enterprise", "US"),
    (15, "churn", 0): ("Enterprise", "US"),
    (15, "churn", 1): ("Enterprise", "US"),
    (15, "cut", 0): ("Enterprise", "US"),
    (15, "cut", 1): ("Enterprise", "GB"),
    (15, "exp", 0): ("Enterprise", "US"),
    (15, "exp", 1): ("Mid-market", "GB"),
    (16, "churn", 0): ("Mid-market", "US"),
    (16, "churn", 1): ("Enterprise", "US"),
    (16, "cut", 0): ("Enterprise", "US"),
    (16, "cut", 1): ("SMB", "GB"),
    (16, "exp", 0): ("Public sector", "US"),
    (16, "exp", 1): ("Enterprise", "US"),
    (17, "churn", 0): ("Enterprise", "US"),
    (17, "churn", 1): ("Enterprise", "US"),
    (17, "cut", 0): ("Enterprise", "GB"),
    (17, "cut", 1): ("Public sector", "JP"),
    (17, "exp", 0): ("Enterprise", "US"),
    (17, "exp", 1): ("Mid-market", "US"),
}


def _loss_place(index, kind, k):
    return _LOSS_PLACE.get((index, kind, k))


def _cover_early_usd(g) -> None:
    """USD rates for Feb–Jul 2024.

    The simulated calendar starts in Aug 2024. Cohort accounts that close
    earlier would otherwise drop out of ARR and fail bookings coverage.
    These rows use a fixed id and a rate of 1, so they do not move the
    generator's id sequence or any later FX draw.
    """
    month = dt.date(2024, 2, 1)
    stop = dt.date(2024, 8, 1)
    i = 0
    while month < stop:
        nxt = add_months(month, 1)
        if ("USD", month) not in g.fx_table:
            g.fx_table[("USD", month)] = 1.0
            stamped = _ts(month, 8)
            g.rows("dated_conversion_rate").append(dict(
                Id=story_sfid("04w", 9000 + i), IsoCode="USD", ConversionRate=1.0,
                StartDate=month, NextStartDate=nxt, CreatedDate=stamped, SystemModstamp=stamped))
        month = nxt
        i += 1


def plant_story(g) -> None:
    if g.as_of != AS_OF:
        return
    _cover_early_usd(g)
    _add_users(g)
    events = []
    g._story_events = events
    g._story_pairs = {"pending": [], "reject": []}

    def acct(n, name, segment, country="US", currency="USD", owner="P. Nair", employees=900):
        return _add_account(g, n, name, segment, country, currency, owner, employees)

    def recurring(a, n, amount, start, end, code="SEAT-ENT", order_type="New", invoice_from=None, owner_line=True):
        ln = _usd_line(g, a, n, amount, code) if currency_ok(a) else _line(g, a, code, amount, 1, n)
        opp = _add_opp(g, a, n, start, amount, ("Closed Won", 100, "Closed"), True, [ln])
        _add_order(g, a, n, opp, start, end, [ln], order_type, invoice_from=invoice_from)
        return opp

    def currency_ok(a):
        return a["CurrencyIsoCode"] == "USD"

    # --- August ARR movements (USD, exact) ---
    term_end = dt.date(2027, 7, 31)
    prior_end = dt.date(2026, 7, 31)
    prior_start = dt.date(2025, 8, 1)
    # In the July 2026 trailing-12 cohort (as of 31 Jul 2025) as well as August's.
    seen_from = dt.date(2025, 7, 1)
    aug = dt.date(2026, 8, 1)

    # Churn: active through July, gone in August.
    for n, name, segment, amount in [
        (101, "Veridian Labs", "Mid-market", 140_000),
        (102, "Northgate Clinics", "Public sector", 100_000),
        (103, "Arcadia Freight", "Enterprise", 60_000),
        (104, "Pellucid AI", "Startups", 60_000),
        (105, "Holloway & Co.", "Enterprise", 40_000),
    ]:
        a = acct(n, name, segment)
        recurring(a, n, amount, seen_from, prior_end)

    # Contraction: July stock drops by the stated amount and stays above zero.
    for n, name, segment, before, after in [
        (111, "Copperline Media", "Enterprise", 280_000, 140_000),
        (112, "Alder & Finch", "Mid-market", 180_000, 90_000),
    ]:
        a = acct(n, name, segment)
        recurring(a, n, before, seen_from, prior_end, order_type="New")
        recurring(a, n + 50, after, aug, term_end, order_type="Renewal")

    # Smaller unnamed movements keep the August bridge in band without entering the top-mover list.
    for i in range(8):
        a = acct(180 + i, f"Lowell Contract {i + 1}", "Mid-market")
        recurring(a, 180 + i, 80_000, seen_from, prior_end)
        recurring(a, 280 + i, 40_000, aug, term_end, order_type="Renewal")
    for i in range(3):
        a = acct(190 + i, f"Pemba Add-on {i + 1}", "Enterprise")
        recurring(a, 190 + i, 100_000, prior_start, term_end)
        recurring(a, 290 + i, 160_000, aug, term_end, order_type="Add-On")

    # One loss month in every trailing-12 window from Jan through Aug 2026.
    # Each account starts a year before it ends, so it is in that window's
    # cohort. August's bridge stays on the planted accounts above.
    owners = list(OWNERS)
    loss_months = []
    yy, mm = 2025, 2
    while (yy, mm) <= (2026, 7):
        loss_months.append(dt.date(yy, mm, 1))
        mm += 1
        if mm == 13:
            yy, mm = yy + 1, 1
    schedule = _loss_schedule()
    for i, loss_start in enumerate(loss_months):
        ended = loss_start - DAY
        opened = add_months(loss_start, -12)
        churns, contractions, expansions = schedule[i]
        for k, amount in enumerate(churns):
            n = 700 if i == 0 and k == 0 else 1000 + i * 3 + k
            name = "Sable Cohort 1" if n == 700 else f"Hale Cohort {i + 1}.{k + 1}"
            placed = _loss_place(i, "churn", k)
            segment, country = placed or ("Mid-market", "US")
            gone = acct(n, name, segment, country=country, owner=owners[(i + k) % len(owners)])
            recurring(gone, n, amount, opened, ended)
        for k, (before, after) in enumerate(contractions):
            n = 1100 + i * 5 + k
            placed = _loss_place(i, "cut", k)
            segment, country = placed or ("Enterprise" if k % 2 == 0 else "Mid-market", "US")
            held = acct(
                n, f"Nereid Seat {i + 1}.{k + 1}",
                segment, country=country,
                owner=owners[(i + k + 3) % len(owners)],
            )
            recurring(held, n, before, opened, ended)
            recurring(held, 1200 + i * 5 + k, after, loss_start, term_end, order_type="Renewal")
        for k, amount in enumerate(expansions):
            n = 1300 + i * 5 + k
            placed = _loss_place(i, "exp", k)
            segment, country = placed or ("Enterprise" if k % 2 == 0 else "Mid-market", "US")
            kept = acct(
                n, f"Orchard Uplift {i + 1}.{k + 1}",
                segment, country=country,
                owner=owners[(i + k + 1) % len(owners)],
            )
            recurring(kept, n, 1_000, opened, term_end)
            recurring(kept, 1400 + i * 5 + k, amount, loss_start, term_end, order_type="Add-On")

    # Expansion on top of a base that stays in force.
    quarry = acct(121, "Quarry Health", "Enterprise", owner="A. Chen")
    recurring(quarry, 121, 200_000, prior_start, term_end)
    recurring(quarry, 122, 480_000, aug, term_end, order_type="Add-On")

    quillon = acct(123, "Quillon Systems", "Enterprise", owner="P. Nair")
    recurring(quillon, 123, 220_000, prior_start, term_end)
    bnb_from = dt.date(2026, 9, 1)
    ln = _usd_line(g, quillon, 124, 350_000)
    opp = _add_opp(g, quillon, 124, _bd_before(AUG_END, 4), 350_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, quillon, 124, opp, _bd_before(AUG_END, 4), add_months(_bd_before(AUG_END, 4), 12) - DAY,
               [ln], "Add-On", invoice_from=bnb_from)

    # New logos that are also booked-not-billed at August month-end.
    solace = acct(131, "Solace Robotics", "Mid-market", owner="P. Nair")
    start = _bd_before(AUG_END, 12)
    ln = _usd_line(g, solace, 131, 620_000, "SEAT-ENT")
    opp = _add_opp(g, solace, 131, start, 620_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, solace, 131, opp, start, add_months(start, 12) - DAY, [ln], "New", invoice_from=bnb_from)

    harbor = acct(132, "Harbor & Pine", "Enterprise", owner="T. Wu")
    start = _bd_before(AUG_END, 7)
    ln = _line(g, harbor, "API-COMMIT", 410_000, 1, 132)
    opp = _add_opp(g, harbor, 132, start, 410_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, harbor, 132, opp, start, add_months(start, 12) - DAY, [ln], "New", invoice_from=bnb_from)

    tern = acct(133, "Tern Logistics", "Mid-market", owner="T. Wu")
    start = _bd_before(AUG_END, 2)
    ln = _line(g, tern, "SUP-PREM", 10, 24_000, 133)
    opp = _add_opp(g, tern, 133, start, 240_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, tern, 133, opp, start, add_months(start, 12) - DAY, [ln], "New", invoice_from=bnb_from)

    arden = acct(134, "Arden Biotech", "Mid-market", owner="P. Nair")
    start = _bd_before(AUG_END, 1)
    ln = _line(g, arden, "SVC-ONB", 12, 15_000, 134)
    opp = _add_opp(g, arden, 134, start, 180_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, arden, 134, opp, start, add_months(start, 12) - DAY, [ln], "New", invoice_from=bnb_from)

    # Won in late August, order on 29 Sep, so August ARR does not include them.
    for n, name, amount, won_on in [
        (141, "Oakridge Analytics", 500_000, dt.date(2026, 8, 20)),
        (142, "Fennel Systems", 400_000, dt.date(2026, 8, 26)),
    ]:
        a = acct(n, name, "Enterprise", owner="A. Chen")
        ln = _usd_line(g, a, n, amount)
        opp = _add_opp(g, a, n, won_on, amount, ("Closed Won", 100, "Closed"), True, [ln])
        _add_order(g, a, n, opp, dt.date(2026, 9, 29), dt.date(2027, 9, 28), [ln], "New",
                   invoice_from=dt.date(2026, 9, 29))

    # --- Deal Desk open queue ---
    def open_won(n, name, segment, amount, age, owner):
        opened = _bd_before(AS_OF, age) if age else AS_OF
        a = acct(n, name, segment, owner=owner)
        ln = _usd_line(g, a, n, max(amount, 1000))
        _add_opp(g, a, n, opened, amount, ("Closed Won", 100, "Closed"), True, [ln], keep_open=True)
        events.append(_event(a, story_sfid("006", n), "won_without_order", opened, None, amount, owner, 3, age))

    def unmatched(n, name, amount, age, owner):
        opened = _bd_before(AS_OF, age)
        a = acct(n, name, "Mid-market", owner=owner)
        events.append(_event(a, story_stripe_id("in_", n), "invoice_unmatched", opened, None, amount, owner, 5, age))
        g._story_unmatched = getattr(g, "_story_unmatched", [])
        g._story_unmatched.append((a, n, amount, opened))

    open_won(201, "Northwind Logistics", "Enterprise", 412_000, 9, "M. Okafor")
    unmatched(202, "Halvorsen Group", 186_000, 6, "J. Reyes")
    # Cancelled order still invoicing.
    ostr = acct(203, "Ostrander Freight", "Enterprise", owner="J. Reyes")
    opened = _bd_before(AS_OF, 4)
    ln = _usd_line(g, ostr, 203, 128_000)
    opp = _add_opp(g, ostr, 203, opened - dt.timedelta(days=20), 128_000, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, ostr, 203, opp, opened - dt.timedelta(days=20), add_months(opened, 12) - DAY, [ln], "New",
               cancel_on=opened - dt.timedelta(days=3))
    events.append(_event(ostr, story_sfid("801", 203), "cancelled_still_invoicing", opened, None, 128_000, "J. Reyes", 2, 4))
    g._story_late_invoice = getattr(g, "_story_late_invoice", [])
    g._story_late_invoice.append((ostr, 203, 128_000, opened))

    open_won(204, "Larkspur Energy", "Enterprise", 530_000, 2, "A. Chen")

    def mismatch(n, name, diff, age, owner):
        opened = _bd_before(AS_OF, age) if age else AS_OF
        a = acct(n, name, "Mid-market", owner=owner)
        ln = _usd_line(g, a, n, 50_000)
        opp = _add_opp(g, a, n, opened, 50_000 + diff, ("Closed Won", 100, "Closed"), True, [ln])
        _add_order(g, a, n, opp, opened, add_months(opened, 12) - DAY, [ln], "New")
        events.append(_event(a, opp["Id"], "amount_mismatch", opened, None, diff, owner, 3, age))

    mismatch(205, "Corvid Robotics", 310_000, 0, "M. Okafor")

    def reduction(n, name, amount, age, owner):
        opened = _bd_before(AS_OF, age)
        a = acct(n, name, "Enterprise", owner=owner)
        base_start = dt.date(2025, 8, 1)
        base = _usd_line(g, a, n, amount)
        opp = _add_opp(g, a, n, base_start, amount, ("Closed Won", 100, "Closed"), True, [base])
        original = _add_order(g, a, n, opp, base_start, dt.date(2027, 7, 31), [base], "New")
        cut = _usd_line(g, a, n + 400, amount)
        cut["qty"] = -1
        cut["total"] = -amount
        red_opp = _add_opp(g, a, n + 400, opened, amount, ("Negotiation/Review", 80, "Commit"), False, [cut])
        _add_order(g, a, n + 400, red_opp, opened, original["EndDate"], [cut], "Reduction",
                   activated=False, reduction=True, original=original["Id"])
        events.append(_event(a, story_sfid("801", n + 400), "reduction_awaiting_approval", opened, None, amount, owner, 5, age))

    reduction(206, "Tidewater Health", 240_000, 1, "M. Okafor")
    unmatched(207, "Pinecrest Media", 205_000, 3, "J. Reyes")
    reduction(208, "Saltmarsh Bank", 150_000, 2, "A. Chen")
    mismatch(209, "Kestrel Bio", 95_000, 2, "A. Chen")
    unmatched(210, "Ferrow Studios", 44_000, 1, "J. Reyes")

    # Resolved in the last 7 days, including Oakridge and Fennel.
    events.append(_event_resolved("Resolved Today A", story_sfid("006", 901), "won_without_order",
                                  dt.date(2026, 9, 29), dt.date(2026, 9, 30), 200_000, "M. Okafor", 3, 1.0))
    events.append(_event_resolved("Resolved Today B", story_sfid("006", 902), "won_without_order",
                                  dt.date(2026, 9, 29), dt.date(2026, 9, 30), 200_000, "A. Chen", 3, 1.0))
    for i in range(9):
        events.append(_event_resolved(
            f"Resolved Early {i}", story_stripe_id("in_", 910 + i), "invoice_unmatched",
            dt.date(2026, 9, 24), dt.date(2026, 9, 25), 180_000, "J. Reyes", 5, 1.0))
    events.append(_event_resolved(
        "Resolved Median", story_sfid("006", 930), "amount_mismatch",
        dt.date(2026, 9, 24), dt.date(2026, 9, 26), 260_000, "M. Okafor", 3, 1.6))
    for i in range(9):
        events.append(_event_resolved(
            f"Resolved Two {i}", story_sfid("006", 940 + i), "won_without_order",
            dt.date(2026, 9, 22), dt.date(2026, 9, 24), 180_000, "A. Chen", 3, 2.0))
    events.append(_event_resolved("Oakridge Analytics", story_sfid("006", 141), "won_without_order",
                                  dt.date(2026, 8, 20), dt.date(2026, 9, 29), 500_000, "A. Chen", 3, 22))
    events.append(_event_resolved("Fennel Systems", story_sfid("006", 142), "won_without_order",
                                  dt.date(2026, 8, 26), dt.date(2026, 9, 29), 400_000, "A. Chen", 3, 18))

    # --- Slipped deals. The close that left Q3 is during the week of 28 Sep.
    # Prior close sits in the last two weeks of September; the new date is spread across Q4.
    slips = [
        (301, "Harbor County Health", "Public sector", 320_000, 2, "S. Ito", dt.date(2026, 9, 18), dt.date(2026, 11, 16), dt.date(2026, 9, 28)),
        (302, "Ostrava Labs", "Enterprise", 240_000, 1, "D. Brennan", dt.date(2026, 9, 22), dt.date(2026, 10, 8), dt.date(2026, 9, 29)),
        (303, "Cinder Freight", "Enterprise", 180_000, 1, "D. Brennan", dt.date(2026, 9, 29), dt.date(2026, 12, 3), dt.date(2026, 9, 30)),
        (304, "Brightline Dental", "SMB", 140_000, 3, "L. Moreau", dt.date(2026, 9, 16), dt.date(2026, 11, 24), dt.date(2026, 9, 28)),
        (305, "Mosaic Transit", "Public sector", 120_000, 1, "S. Ito", dt.date(2026, 9, 24), dt.date(2026, 10, 27), dt.date(2026, 9, 29)),
        (306, "Orbit Supply", "Mid-market", 100_000, 2, "K. Adeyemi", dt.date(2026, 9, 17), dt.date(2026, 12, 15), dt.date(2026, 9, 30)),
    ]
    for n, name, segment, amount, slips_n, owner, old_close, new_close, changed_on in slips:
        a = acct(n, name, segment, owner=owner)
        ln = _usd_line(g, a, n, amount, "SEAT-TEAM" if segment != "Enterprise" else "SEAT-ENT")
        created = dt.date(2026, 7, 6)
        history = [(created, "Prospecting", 10, "Pipeline", amount, dt.date(2026, 8, 14))]
        for s in range(slips_n - 1):
            interim = old_close if s == slips_n - 2 else dt.date(2026, 9, 4)
            history.append((dt.date(2026, 8, 6 + s * 6), "Negotiation/Review", 80, "Commit", amount, interim))
        if slips_n == 1:
            history[0] = (created, "Prospecting", 10, "Pipeline", amount, old_close)
        history.append((changed_on, "Negotiation/Review", 80, "Commit", amount, new_close))
        _add_opp(g, a, n, new_close, amount, ("Negotiation/Review", 80, "Commit"), False, [ln],
                 slip_history=history)

    # --- Account-match pairs ---
    def pair(n, name_a, name_b, currency, country, arr_on_a):
        a = acct(n, name_a, "Enterprise", country, currency, "A. Chen", 1200)
        b = acct(n + 1, name_b, "Enterprise", country, currency, "A. Chen", 400)
        b["Website"] = f"{_slug(name_b)}.io"
        if arr_on_a:
            ln = _line(g, a, "SEAT-ENT", 1, arr_on_a, n) if currency == "USD" else _line(
                g, a, "SEAT-ENT", arr_on_a, g.pbe[("SEAT-ENT", currency)][1], n)
            if currency != "USD":
                # ARR target is USD; qty * unit / rate. Use USD accounts for the dollar amounts.
                pass
            opp = _add_opp(g, a, n, dt.date(2026, 1, 15), arr_on_a, ("Closed Won", 100, "Closed"), True, [ln])
            _add_order(g, a, n, opp, dt.date(2026, 1, 15), dt.date(2026, 12, 31), [ln], "New")
        return a["Id"], b["Id"]

    mer_a, mer_b = pair(401, "Meridian Analytics Inc", "Meridan Analytics", "USD", "US", 310_000)
    # Brightwater: same normalized name, different domains, same currency.
    br_a = acct(403, "Brightwater Systems GmbH", "Enterprise", "DE", "EUR", "A. Chen", 900)
    br_b = acct(404, "Brightwater Systems", "Enterprise", "DE", "EUR", "A. Chen", 200)
    br_b["Website"] = "brightwater-systems.io"
    rate = g.fx( "EUR", dt.date(2026, 1, 15))
    eur_amount = money(190_000 * rate, "EUR")
    ln = _line(g, br_a, "SEAT-ENT", 1, eur_amount, 403)
    opp = _add_opp(g, br_a, 403, dt.date(2026, 1, 15), eur_amount, ("Closed Won", 100, "Closed"), True, [ln])
    _add_order(g, br_a, 403, opp, dt.date(2026, 1, 15), dt.date(2026, 12, 31), [ln], "New")
    g._story_pairs["pending"] = [(mer_a, mer_b), (br_a["Id"], br_b["Id"])]
    # Halvorsen Group is the unmatched-invoice account (n=202). The typo twin is separate.
    twin = acct(406, "Halverson Group", "Enterprise", "US", "USD", "J. Reyes", 300)
    twin["Website"] = "halverson-group.io"
    g._story_pairs["reject"] = [(story_sfid("001", 202), twin["Id"])]
    g._story_pairs["pending_names"] = [
        ["Meridian Analytics Inc", "Meridan Analytics"],
        ["Brightwater Systems GmbH", "Brightwater Systems"],
    ]

    # Three small JPY orders whose invoices are scaled after billing.
    g._jpy_defect_orders = []
    rate = g.fx("JPY", dt.date(2026, 8, 3))
    true_yen = money((100_000 / 3) * rate / 99, "JPY")
    for i in range(3):
        a = acct(501 + i, f"Yen Defect {i + 1}", "SMB", "JP", "JPY", "T. Wu", 80)
        ln = _line(g, a, "SEAT-TEAM", 1, true_yen, 501 + i)
        opp = _add_opp(g, a, 501 + i, dt.date(2026, 8, 3), true_yen, ("Closed Won", 100, "Closed"), True, [ln])
        order = _add_order(g, a, 501 + i, opp, dt.date(2026, 8, 3), dt.date(2027, 8, 2), [ln], "New")
        order["_jpy_scale_defect"] = True
        g._jpy_defect_orders.append(order["Id"])

    _write_activity(g, events)
    truth = ROOT / "data" / "truth"
    truth.mkdir(parents=True, exist_ok=True)
    (truth / "story_ids.json").write_text(json.dumps(g._story_pairs, indent=2))


def currency_ok(a):
    return True


def _event(acct, record_id, exception_type, opened, resolved, amount, owner, sla, age):
    return dict(
        account_name=acct["Name"] if not isinstance(acct, str) else acct,
        record_id=record_id, exception_type=exception_type,
        opened_on=opened, resolved_on=resolved, amount_usd=amount,
        owner_name=owner, sla_bd=sla, age_days=age)


def _event_resolved(name, record_id, exception_type, opened, resolved, amount, owner, sla, age):
    return dict(
        account_name=name, record_id=record_id, exception_type=exception_type,
        opened_on=opened, resolved_on=resolved, amount_usd=amount,
        owner_name=owner, sla_bd=sla, age_days=age)


def _write_activity(g, events) -> None:
    out = ROOT / "data" / "raw" / "story"
    out.mkdir(parents=True, exist_ok=True)
    frame = pd.DataFrame(events)
    frame["resolved_on"] = frame["resolved_on"].map(lambda d: d.isoformat() if d else "open")
    frame["opened_on"] = frame["opened_on"].map(lambda d: d.isoformat() if hasattr(d, "isoformat") else d)
    frame.to_csv(out / "deal_desk_exception.csv", index=False)


def plant_billing_defects(g) -> None:
    if g.as_of != AS_OF:
        return
    defect_orders = set(getattr(g, "_jpy_defect_orders", []))
    for inv in g.rows("invoice"):
        if inv.get("_true_order_id") not in defect_orders:
            continue
        for key in ("subtotal", "total", "amount_due", "amount_paid", "amount_remaining"):
            inv[key] = int(inv[key]) * 100
        inv_id = inv["id"]
        for line in g.rows("invoice_line_item"):
            if line["invoice_id"] == inv_id:
                line["amount"] = int(line["amount"]) * 100
                line["unit_amount_decimal"] = float(line["unit_amount_decimal"]) * 100

    # Planted unmatched invoices and the post-cancel invoice. Created directly so they
    # are not part of the random 7% metadata miss.
    for acct, n, amount, opened in getattr(g, "_story_unmatched", []):
        _manual_invoice(g, acct, n, amount, opened, order_id=None)
    for acct, n, amount, opened in getattr(g, "_story_late_invoice", []):
        _manual_invoice(g, acct, n, amount, opened, order_id=story_sfid("801", n))

    # Three closed-month unmatched invoices, one each in USD, EUR, and JPY.
    # Paid before month-end so they bill and miss the tie-out without sitting in AR.
    # Together with the JPY scale defect this puts unmatched value above 1%.
    sable = next(a for a in g.accounts if a["Name"] == "Sable Cohort 1")
    brightwater = next(a for a in g.accounts if a["Name"] == "Brightwater Systems")
    yen = next(a for a in g.accounts if a["Name"] == "Yen Defect 1")
    _manual_invoice(g, sable, 801, 120_000, dt.date(2026, 8, 12), order_id=None)
    eur_local = money(100_000 * g.fx("EUR", dt.date(2026, 8, 14)), "EUR")
    _manual_invoice(g, brightwater, 802, eur_local, dt.date(2026, 8, 14), order_id=None)
    jpy_local = money(80_000 * g.fx("JPY", dt.date(2026, 8, 18)), "JPY")
    _manual_invoice(g, yen, 803, jpy_local, dt.date(2026, 8, 18), order_id=None)
    # July has one unmatched invoice, also paid inside the month.
    _manual_invoice(g, sable, 804, 40_000, dt.date(2026, 7, 16), order_id=None, paid_on=dt.date(2026, 7, 28))
    # Over-90 that is written off before August, so March has a balance and August does not.
    for i, amount in enumerate((50_000, 50_000, 50_000, 40_000)):
        opened = dt.date(2025, 11, 10)
        _manual_invoice(
            g, sable, 810 + i, amount, opened, order_id=None,
            uncollectible_on=opened + dt.timedelta(days=181))
    # Still open past 90 at August, not old enough to write off.
    # The two larger ones are collected in August, so they age into over-90 and then leave.
    for i, amount in enumerate((80_000, 70_000)):
        _manual_invoice(
            g, sable, 820 + i, amount, dt.date(2026, 4, 20), order_id=None,
            paid_on=dt.date(2026, 8, 15))
    for i, amount in enumerate((60_000, 50_000)):
        _manual_invoice(g, sable, 822 + i, amount, dt.date(2026, 4, 20), order_id=None)
    # Matched invoices that hold AR just long enough for DSO to rise Mar→Aug
    # and land in the mid-40s in August. Tied to an order so they are not unmatched.
    anchor = story_sfid("801", 700)
    _manual_invoice(g, sable, 830, 2_400_000, dt.date(2026, 5, 20), order_id=anchor)
    _manual_invoice(g, sable, 831, 3_600_000, dt.date(2026, 5, 1), order_id=anchor, paid_on=dt.date(2026, 6, 10))
    _manual_invoice(g, sable, 832, 1_000_000, dt.date(2026, 7, 1), order_id=anchor, paid_on=dt.date(2026, 8, 10))
    _manual_invoice(g, sable, 833, 750_000, dt.date(2026, 4, 2), order_id=anchor, paid_on=dt.date(2026, 5, 12))
    # Open only in August, so DSO clears 45 days after the cohort was
    # restated. Matched to an order so it does not add unmatched billings.
    _manual_invoice(g, sable, 834, 480_000, dt.date(2026, 8, 20), order_id=anchor)


def _manual_invoice(g, acct, n, amount, opened, order_id, uncollectible_on=None, paid_on=None):
    cur = acct["CurrencyIsoCode"]
    cust = story_stripe_id("cus_", n)
    if cust not in {c["id"] for c in g.rows("customer")}:
        g.rows("customer").append(dict(
            id=cust, name=acct["Name"], email=f"ap@{acct['Website'].replace('www.', '')}",
            currency=cur.lower(), metadata_salesforce_account_id=acct["Id"],
            created=_ts(opened, 7), delinquent=False, _updated=_ts(opened, 7)))
    iid = story_stripe_id("in_", n)
    total = minor(amount, cur)
    created = _ts(opened, 8)
    g.rows("invoice").append(dict(
        id=iid, customer_id=cust, number=f"INV-{n:04d}", status="open",
        billing_reason="manual", collection_method="send_invoice", currency=cur.lower(),
        subtotal=total, total=total, amount_due=total, amount_paid=0, amount_remaining=total,
        created=created, period_start=opened, period_end=add_months(opened, 1) - DAY,
        due_date=created + dt.timedelta(days=30), status_transitions_paid_at=None,
        status_transitions_marked_uncollectible_at=_ts(uncollectible_on, 9) if uncollectible_on else None,
        metadata_salesforce_order_id=order_id, _true_order_id=order_id, _updated=created))
    if uncollectible_on:
        g.rows("invoice")[-1].update(status="uncollectible")
    if paid_on:
        paid = g.rows("invoice")[-1]
        paid.update(
            status="paid", amount_paid=paid["total"], amount_remaining=0,
            status_transitions_paid_at=_ts(paid_on, 16))
    g.rows("invoice_line_item").append(dict(
        id=story_stripe_id("il_", n), invoice_id=iid, type="invoiceitem", description="Manual invoice",
        quantity=1, unit_amount_decimal=round(amount * (1 if cur == "JPY" else 100), 4),
        amount=total, currency=cur.lower(), period_start=opened,
        period_end=add_months(opened, 1) - DAY, proration=False,
        metadata_product_code="SEAT-ENT", metadata_salesforce_order_item_id=None, _updated=created))


def rebalance_fy26_bookings(g) -> None:
    """Move non-story won close dates inside Jan–Jun so no month of new and expansion
    order ACV is under half or over 175% of the Jan–Aug mean. Opportunity amount is
    the wrong measure: the page books the order. July and August stay put, so Q3 won
    and the August bookings ratio are unchanged. Does not touch the RNG."""
    if g.as_of != AS_OF:
        return
    frozen = getattr(g, "_frozen_opps", set())
    orders_by_opp = {}
    for order in g.rows("order"):
        oid = order.get("OpportunityId")
        if oid:
            orders_by_opp.setdefault(oid, []).append(order)

    def acv(opp):
        total = 0.0
        close = opp["CloseDate"]
        for order in orders_by_opp.get(opp["Id"], []):
            if order.get("IsReductionOrder") or order.get("Type") not in ("New", "Add-On"):
                continue
            rate = g.fx(order.get("CurrencyIsoCode") or "USD", close) or 1
            for item in order.get("_items") or []:
                if item.get("EndDate") is not None:
                    total += float(item["Quantity"]) * float(item["UnitPrice"]) / rate
        return total

    start, end = dt.date(2026, 1, 1), dt.date(2026, 8, 31)
    won = [
        opp for opp in g.rows("opportunity")
        if opp.get("IsWon") and isinstance(opp.get("CloseDate"), dt.date) and start <= opp["CloseDate"] <= end
    ]
    movable = [opp for opp in won if opp["Id"] not in frozen]

    def totals():
        buckets = {month: 0.0 for month in range(1, 9)}
        for opp in won:
            close = opp["CloseDate"]
            if isinstance(close, dt.date) and start <= close <= end:
                buckets[close.month] += acv(opp)
        return buckets

    def move(opp, month):
        old = opp["CloseDate"]
        new = dt.date(2026, month, 15)
        if old == new:
            return
        opp["CloseDate"] = new
        for row in g.rows("opportunity_history"):
            if row.get("OpportunityId") == opp["Id"] and row.get("CloseDate") == old:
                row["CloseDate"] = new

    free = list(range(1, 7))
    for _ in range(8000):
        buckets = totals()
        total = sum(buckets.values())
        if total <= 0:
            return
        mean = total / 8
        if all(0.50 * mean <= buckets[month] <= 1.75 * mean for month in range(1, 9)):
            return
        hi = max(free, key=lambda month: buckets[month])
        candidates = [opp for opp in movable if opp["CloseDate"].month == hi and acv(opp) > 0]
        candidates.sort(key=lambda opp: (acv(opp), opp["Id"]))
        placed = False
        for lo in sorted(free, key=lambda month: buckets[month]):
            if lo == hi:
                continue
            room = 1.75 * mean - buckets[lo]
            floor = 0.50 * mean
            chosen = next(
                (opp for opp in candidates if acv(opp) <= room and buckets[hi] - acv(opp) >= floor),
                None,
            )
            if chosen is not None:
                move(chosen, lo)
                placed = True
                break
        if not placed:
            print("bookings rebalance stopped", {m: round(buckets[m] / mean, 3) for m in range(1, 9)})
            return
