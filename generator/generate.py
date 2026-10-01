"""Synthetic quote-to-cash source data: Salesforce standard objects + a Stripe-shaped billing system.

Output mirrors what a Fivetran-style connector lands in a warehouse: one table per object,
current-state rows, Salesforce API field names verbatim, Stripe field names verbatim
(amounts in minor units, zero-decimal JPY, lowercase currency codes), plus `_loaded_at`
(the sync_end of the first successful connector run at or after the row changed).
`data/raw/fivetran_log/connector_sync.csv` is the hourly sync log for the last 14 days.

Usage:
    python generator/generate.py                     # as_of = today (UTC), now = wall clock
    python generator/generate.py --as-of 2026-09-27  # pinned: byte-identical output
"""
from __future__ import annotations

import argparse
import calendar
import datetime as dt
import re
import string
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
B62 = string.digits + string.ascii_uppercase + string.ascii_lowercase
DAY = dt.timedelta(days=1)

STAGES = [  # (StageName, Probability, ForecastCategoryName)
    ("Prospecting", 10, "Pipeline"),
    ("Qualification", 20, "Pipeline"),
    ("Needs Analysis", 40, "Pipeline"),
    ("Proposal/Price Quote", 60, "Best Case"),
    ("Negotiation/Review", 80, "Commit"),
]
WON = ("Closed Won", 100, "Closed")
LOST = ("Closed Lost", 0, "Omitted")
INDUSTRIES = ["Technology", "Financial Services", "Healthcare", "Retail", "Manufacturing",
              "Media", "Education", "Professional Services", "Logistics", "Energy"]
NAME_A = ["Acme", "Northwind", "Blue Harbor", "Cobalt", "Summit", "Redwood", "Lumen", "Granite",
          "Harbor", "Vertex", "Juniper", "Meridian", "Atlas", "Beacon", "Cedar", "Driftwood",
          "Ember", "Fjord", "Halcyon", "Ironclad", "Kestrel", "Larkspur", "Monarch", "Nimbus",
          "Obsidian", "Pioneer", "Quarry", "Riverstone", "Sable", "Tidewater", "Umber", "Vantage",
          "Willow", "Yarrow", "Zephyr", "Alder", "Brightline", "Copperleaf", "Delta", "Evergreen"]
NAME_B = ["Analytics", "Health", "Logistics", "Robotics", "Capital", "Labs", "Systems", "Foods",
          "Energy", "Media", "Software", "Networks", "Bio", "Freight", "Insurance", "Learning",
          "Security", "Retail", "Dynamics", "Materials", "Mobility", "Payments", "Studios", "Works"]
NAME_C = ["Inc.", "LLC", "Group", "Co.", "Corp.", "Ltd.", "GmbH", "Holdings", ""]
US_STATES = ["CA", "NY", "TX", "WA", "MA", "IL", "CO", "GA", "FL", "NC", "AZ", "OR"]


# ---------------------------------------------------------------- helpers
def add_months(d: dt.date, n: int) -> dt.date:
    y, m = divmod(d.month - 1 + n, 12)
    y += d.year
    m += 1
    return dt.date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def month_start(d: dt.date) -> dt.date:
    return d.replace(day=1)


def dp(cur: str) -> int:
    return 0 if cur == "JPY" else 2


def money(x: float, cur: str) -> float:
    return round(float(x), dp(cur))


def minor(x: float, cur: str) -> int:
    """Stripe minor units. JPY is zero-decimal."""
    return int(round(x if cur == "JPY" else x * 100))


def fmt(t) -> str | None:
    if t is None or (isinstance(t, float) and np.isnan(t)):
        return None
    if isinstance(t, dt.datetime):
        return t.strftime("%Y-%m-%d %H:%M:%S")
    return t.isoformat()


def sf_suffix(id15: str) -> str:
    """Salesforce 15->18 char case-safe checksum (the real algorithm)."""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
    out = ""
    for i in range(3):
        chunk = id15[i * 5:(i + 1) * 5]
        out += alphabet[sum(1 << j for j, c in enumerate(chunk) if c.isupper())]
    return out


def _name_key(name: str) -> str:
    """Same normalization as int_accounts__deduped. Used only to construct cases."""
    s = re.sub(r"\s*\([^)]*\)", "", name.lower())
    s = re.sub(r"[^a-z0-9]+", " ", s.replace(".", "")).strip()
    s = re.sub(r"(\s+(incorporated|holdings|group|corp|gmbh|llc|ltd|inc|kk|co))+$", "", s)
    return s.strip()


def _domain_key(website: str | None) -> str | None:
    if not website:
        return None
    host = re.sub(r"^www\.", "", re.sub(r"^https?://", "", website.lower())).split("/", 1)[0]
    return host or None


def _drop_first_vowel(name: str) -> str:
    for i, ch in enumerate(name):
        if ch.lower() in "aeiou":
            return name[:i] + name[i + 1:]
    return name + "x"


def b62(n: int, width: int) -> str:
    s = ""
    while n:
        n, r = divmod(n, 62)
        s = B62[r] + s
    return s.rjust(width, "0")


@dataclass
class Gen:
    cfg: dict
    as_of: dt.date
    now: dt.datetime
    rng: np.random.Generator = field(init=False)
    counters: dict = field(default_factory=dict)
    t: dict = field(default_factory=lambda: {})  # table name -> list[dict]

    def __post_init__(self):
        self.rng = np.random.default_rng(self.cfg["seed"])
        self.start = add_months(self.as_of, -self.cfg["history_months"])
        self.last_event_day = self.as_of - DAY          # business events end yesterday
        mess = self.cfg["mess"]
        self.sf_sync = max(self.now - dt.timedelta(minutes=mess["salesforce_sync_lag_minutes"]),
                           dt.datetime.combine(self.as_of, dt.time()))
        self.billing_sync = self.now - dt.timedelta(hours=mess["billing_sync_lag_hours"])
        self.products = {p["code"]: p for p in self.cfg["products"]}
        self.curs = self.cfg["currencies"]

    # --- primitives
    def rows(self, name):
        return self.t.setdefault(name, [])

    def sfid(self, prefix: str) -> str:
        n = self.counters[prefix] = self.counters.get(prefix, 0) + 1
        body = prefix + "8a0" + b62(n * 7919 % 62 ** 9, 9)  # scrambled but unique
        return body + sf_suffix(body)

    def stripe_id(self, prefix: str) -> str:
        return prefix + "".join(self.rng.choice(list(B62), 14))

    def seq(self, key: str) -> int:
        n = self.counters[key] = self.counters.get(key, 0) + 1
        return n

    def u(self, a, b):
        return float(self.rng.uniform(a, b))

    def i(self, a, b):
        return int(self.rng.integers(a, b + 1))

    def p(self, prob) -> bool:
        return bool(self.rng.random() < prob)

    def ts(self, d: dt.date, h0=8, h1=19) -> dt.datetime:
        return dt.datetime.combine(d, dt.time()) + dt.timedelta(seconds=self.i(h0 * 3600, h1 * 3600 - 1))

    def fx(self, cur: str, d: dt.date) -> float:
        return self.fx_table[(cur, month_start(d))]

    # ------------------------------------------------------------ reference data
    def build_reference(self):
        # Users (sales reps)
        first = ["Avery", "Jordan", "Riley", "Casey", "Morgan", "Quinn", "Parker", "Reese", "Rowan",
                 "Skyler", "Emerson", "Finley", "Hayden", "Jamie", "Kai", "Logan", "Peyton", "Sage"]
        last = ["Nguyen", "Patel", "Garcia", "Kim", "Okafor", "Silva", "Cohen", "Rossi", "Murphy",
                "Tanaka", "Schmidt", "Dubois", "Haddad", "Larsen", "Moreno", "Walsh", "Ito", "Brooks"]
        self.reps = []
        for k in range(self.cfg["volumes"]["sales_reps"]):
            uid = self.sfid("005")
            self.reps.append(uid)
            ts = self.ts(self.start - dt.timedelta(days=self.i(30, 400)))
            self.rows("user").append(dict(
                Id=uid, Name=f"{first[k % len(first)]} {last[(k * 7) % len(last)]}",
                Title=["Account Executive", "Senior Account Executive", "Account Manager"][k % 3],
                IsActive=k < self.cfg["volumes"]["sales_reps"] - 3,
                CreatedDate=ts, SystemModstamp=ts))

        # DatedConversionRate: monthly corporate rates (units per USD)
        self.fx_table = {}
        m = month_start(add_months(self.start, -1))
        levels = {c: v["rate"] for c, v in self.curs.items()}
        while m <= month_start(self.as_of):
            nxt = add_months(m, 1)
            for cur, base in self.curs.items():
                if cur != "USD":
                    levels[cur] *= float(np.exp(self.rng.normal(0, 0.015)))
                    levels[cur] = float(np.clip(levels[cur], base["rate"] * 0.9, base["rate"] * 1.1))
                rate = round(levels[cur], 6)
                self.fx_table[(cur, m)] = rate
                ts = self.ts(m - dt.timedelta(days=2))
                self.rows("dated_conversion_rate").append(dict(
                    Id=self.sfid("04w"), IsoCode=cur, ConversionRate=rate, StartDate=m,
                    NextStartDate=nxt, CreatedDate=ts, SystemModstamp=ts))
            m = nxt

        # Product2, Pricebook2, PricebookEntry (one entry per product x currency x pricebook)
        created = self.ts(self.start - dt.timedelta(days=200))
        std, com = self.sfid("01s"), self.sfid("01s")
        self.pricebook_id = com
        for pid, name, is_std in [(std, "Standard Price Book", True), (com, "Commercial List Prices", False)]:
            self.rows("pricebook2").append(dict(Id=pid, Name=name, IsActive=True, IsStandard=is_std,
                                                Description=None, CreatedDate=created, SystemModstamp=created))
        self.pbe = {}
        for code, p in self.products.items():
            p2 = self.sfid("01t")
            p["Id"] = p2
            self.rows("product2").append(dict(
                Id=p2, Name=p["name"], ProductCode=code, Family=p["family"], IsActive=True,
                QuantityUnitOfMeasure=p["uom"], Description=None, CreatedDate=created, SystemModstamp=created))
            for pbid in (std, com):
                for cur, c in self.curs.items():
                    price = money(p["list_usd"] * c["rate"], cur) if p["list_usd"] >= 1 \
                        else round(p["list_usd"] * c["rate"], 4)
                    if code in ("API-COMMIT", "API-OVER"):
                        price = round(p["list_usd"] * c["rate"], 4)
                    eid = self.sfid("01u")
                    if pbid == com:
                        self.pbe[(code, cur)] = (eid, price)
                    self.rows("pricebook_entry").append(dict(
                        Id=eid, Pricebook2Id=pbid, Product2Id=p2, ProductCode=code, CurrencyIsoCode=cur,
                        UnitPrice=price, IsActive=True, UseStandardPrice=pbid == com,
                        CreatedDate=created, SystemModstamp=created))

    # ------------------------------------------------------------ accounts
    def build_accounts(self):
        n = self.cfg["volumes"]["accounts"]
        curs = list(self.curs)
        weights = np.array([self.curs[c]["weight"] for c in curs])
        weights /= weights.sum()
        extra = ["Partners", "Industries", "Technologies", "Solutions", "Ventures", "Brands", "Aerospace",
                 "Therapeutics", "Outfitters", "Collective", "Instruments", "Marine", "Pharma", "Telecom", "Agritech", "Motors"]
        pool = sorted({f"{a} {b}" for a in NAME_A for b in NAME_B + extra})
        pool += sorted({f"{a} & {b}" for a in NAME_A for b in NAME_A if a < b})
        assert len(pool) >= n, "not enough unique company names for configured volume"
        self.accounts = []
        for base in self.rng.permutation(pool)[:n]:
            base = str(base)
            cur = str(self.rng.choice(curs, p=weights))
            country = str(self.rng.choice(self.curs[cur]["countries"]))
            emp = int(np.clip(self.rng.lognormal(5.5, 1.4), 5, 80000))
            seg = "SMB" if emp < 200 else "MM" if emp < 2000 else "ENT"
            suffix = "GmbH" if country == "DE" else "Ltd." if country in ("GB", "IE") \
                else "K.K." if country == "JP" else str(self.rng.choice(NAME_C[:4]))
            created = self.ts(self.start + dt.timedelta(days=self.i(-120, (self.as_of - self.start).days - 45)))
            a = dict(Id=self.sfid("001"), Name=f"{base} {suffix}".strip(), base=base,
                     Website=f"www.{''.join(ch for ch in base.lower() if ch.isalnum())}.com", Industry=str(self.rng.choice(INDUSTRIES)),
                     NumberOfEmployees=emp, segment=seg, BillingCountry=country,
                     BillingState=str(self.rng.choice(US_STATES)) if country == "US" else None,
                     CurrencyIsoCode=cur, OwnerId=str(self.rng.choice(self.reps)), CreatedDate=created,
                     dup=None, canonical=None, last_touch=created, won_any=False, active_contracts=0,
                     case_type="canonical", ParentId=None)
            a["canonical"] = a["Id"]
            self.accounts.append(a)

        # duplicates: a second Account for the same company, created later by a different rep
        for a in list(self.accounts):
            if self.p(self.cfg["mess"]["duplicate_account"]):
                variant = self.rng.choice([
                    a["base"].upper(), f"{a['base']}, Inc.", f"{a['base']} Incorporated", a["base"],
                    f"{a['base']} ({a['BillingCountry']})"])
                d = dict(a, Id=self.sfid("001"), Name=str(variant), OwnerId=str(self.rng.choice(self.reps)),
                         Website=self.rng.choice([a["Website"], a["Website"].replace("www.", "https://"), None]),
                         BillingState=None, dup=None, canonical=a["Id"], case_type="original", ParentId=None,
                         CreatedDate=min(a["CreatedDate"] + dt.timedelta(days=self.i(20, 300)),
                                         self.ts(self.last_event_day - dt.timedelta(days=30))),
                         NumberOfEmployees=None if self.p(0.5) else a["NumberOfEmployees"])
                d["last_touch"] = d["CreatedDate"]
                a["dup"] = d
                self.accounts.append(d)

    # ------------------------------------------------------------ deal shapes
    def nb_lines(self, seg):
        mix = self.rng.choice(["seats", "api", "both"], p=[0.5, 0.3, 0.2])
        lines = []
        if mix in ("seats", "both"):
            code = "SEAT-TEAM" if seg == "SMB" or (seg == "MM" and self.p(0.5)) else "SEAT-ENT"
            qty = {"SMB": (5, 60), "MM": (40, 400), "ENT": (200, 3000)}[seg]
            disc = {"SMB": (0, 10), "MM": (5, 20), "ENT": (10, 30)}[seg]
            lines.append([code, self.i(*qty), round(self.u(*disc))])
            if seg != "SMB" and self.p(0.4):
                lines.append(["SUP-PREM", 1, round(self.u(0, 15))])
        if mix in ("api", "both"):
            lo, hi = {"SMB": (20, 100), "MM": (100, 750), "ENT": (500, 5000)}[seg]
            credits = self.i(lo, hi) * 1000
            lines.append(["API-COMMIT", credits, round(min(25, credits / 200_000) + self.u(0, 5))])
        if self.p(0.3):
            lines.append(["SVC-ONB", self.i(1, 4), round(self.u(0, 20))])
        return lines

    # ------------------------------------------------------------ opportunity engine
    def make_opp(self, acct, opp_type, created: dt.date, cycle_days: int, lines_spec, win_rate, name_suffix=""):
        cur = acct["CurrencyIsoCode"]
        planned_close = created + dt.timedelta(days=cycle_days)
        path = STAGES if opp_type == "New Business" else STAGES[2:]
        # Decide outcome
        if planned_close <= self.last_event_day:
            won = self.p(win_rate)
            reached = len(path) - 1 if won else self.i(0, len(path) - 1)
            close = planned_close if won else created + dt.timedelta(
                days=max(1, int(cycle_days * (reached + 1) / len(path) * self.u(0.8, 1.0))))
            final = WON if won else LOST
            closed = True
        else:
            won, closed = False, False
            frac = (self.last_event_day - created).days / cycle_days
            reached = int(np.clip(np.floor(frac * len(path)), 0, len(path) - 1))
            close, final = planned_close, path[reached]
        stage_dates = [created + dt.timedelta(days=int(k * (min(close, self.last_event_day) - created).days
                                                         / max(1, len(path))))
                       for k in range(len(path))]

        # Lines (products get added once Needs Analysis is reached)
        oid = self.sfid("006")
        has_lines = lines_spec and path[reached][0] in ("Needs Analysis", "Proposal/Price Quote", "Negotiation/Review")
        lines = []
        if has_lines:
            for code, qty, disc in lines_spec:
                eid, list_price = self.pbe[(code, cur)]
                unit = round(list_price * (1 - disc / 100), 4 if code == "API-COMMIT" else dp(cur))
                lines.append(dict(code=code, qty=qty, disc=disc, list=list_price, unit=unit, pbe=eid,
                                  total=money(qty * unit, cur)))
        line_total = money(sum(l["total"] for l in lines), cur)
        estimate = money(round(max(line_total, 5000 * self.curs[cur]["rate"]) * self.u(0.6, 1.4), -3), cur)
        amount = line_total if lines else estimate
        if closed and won and self.p(self.cfg["mess"]["amount_override"]):
            amount = money(round(line_total * self.u(0.9, 1.1), -2), cur)

        # Close-date slip on some deals: earlier history rows carry the original CloseDate
        slip_at = self.i(1, len(path) - 1) if self.p(0.25) and reached >= 1 else None
        orig_close = close - dt.timedelta(days=self.i(14, 60)) if slip_at else close

        owner = acct["OwnerId"]
        hist = []
        for k in range(reached + 1):
            s, prob, fc = path[k]
            a = amount if (lines and s in ("Proposal/Price Quote", "Negotiation/Review")) else estimate
            if not lines:
                a = amount
            cd = close if (slip_at and k >= slip_at) else orig_close
            hist.append((stage_dates[k], s, prob, fc, a, cd))
        if closed:
            hist.append((close, final[0], final[1], final[2], amount, close))
        created_ts = self.ts(created)
        for k, (d, s, prob, fc, a, cd) in enumerate(hist):
            t = created_ts if k == 0 else self.ts(d)
            self.rows("opportunity_history").append(dict(
                Id=self.sfid("008"), OpportunityId=oid, StageName=s, Amount=a,
                ExpectedRevenue=money(a * prob / 100, cur), CloseDate=cd, Probability=prob, ForecastCategory=fc,
                CreatedById=owner, CreatedDate=t, SystemModstamp=t, IsDeleted=False))
        last_mod = max(self.ts(hist[-1][0]), created_ts)

        # Quotes once Proposal is reached
        synced_quote, quote_lines = None, []
        prop_idx = path.index(STAGES[3])
        if lines and reached >= prop_idx:
            prop_date = stage_dates[prop_idx]
            n_q = self.i(1, 3)
            for q in range(n_q):
                last = q == n_q - 1
                qd = min(prop_date + dt.timedelta(days=q * self.i(3, 12)), min(close, self.last_event_day))
                qid, q_ts = self.sfid("0Q0"), self.ts(qd)
                bump = 0 if last else (n_q - 1 - q) * self.i(2, 5)  # earlier quotes: less discount
                qls = []
                for n, l in enumerate(lines):
                    disc = max(0, l["disc"] - bump)
                    unit = round(l["list"] * (1 - disc / 100), 4 if l["code"] == "API-COMMIT" else dp(cur))
                    qlid = self.sfid("0QL")
                    qls.append(dict(l, qlid=qlid, unit=unit, disc=disc, total=money(l["qty"] * unit, cur)))
                    self.rows("quote_line_item").append(dict(
                        Id=qlid, QuoteId=qid, Product2Id=self.products[l["code"]]["Id"], PricebookEntryId=l["pbe"],
                        Quantity=l["qty"], ListPrice=l["list"], UnitPrice=unit, Discount=disc,
                        TotalPrice=money(l["qty"] * unit, cur), ServiceDate=None, LineNumber=f"{n + 1:08d}",
                        CurrencyIsoCode=cur, CreatedDate=q_ts, SystemModstamp=q_ts, IsDeleted=False))
                if last:
                    status = "Accepted" if won else "Denied" if closed else str(
                        self.rng.choice(["Presented", "Needs Review", "In Review"]))
                    synced_quote, quote_lines = qid, qls
                else:
                    status = str(self.rng.choice(["Rejected", "Presented"]))
                subtotal = money(sum(x["qty"] * x["list"] for x in qls), cur)
                total = money(sum(x["total"] for x in qls), cur)
                self.rows("quote").append(dict(
                    Id=qid, Name=f"Q-{self.seq('quote'):05d}", QuoteNumber=f"{self.counters['quote']:08d}",
                    OpportunityId=oid, AccountId=acct["Id"], Pricebook2Id=self.pricebook_id, Status=status,
                    IsSyncing=last, ExpirationDate=qd + dt.timedelta(days=30), Subtotal=subtotal,
                    Discount=round(100 * (1 - total / subtotal), 2) if subtotal else 0, TotalPrice=total,
                    GrandTotal=total, CurrencyIsoCode=cur, CreatedDate=q_ts,
                    SystemModstamp=self.ts(min(close, self.last_event_day)) if last else q_ts, IsDeleted=False))
            lines = quote_lines  # opp lines sync from the synced quote

        for l in lines:
            self.rows("opportunity_line_item").append(dict(
                Id=self.sfid("00k"), OpportunityId=oid, PricebookEntryId=l["pbe"],
                Product2Id=self.products[l["code"]]["Id"], ProductCode=l["code"], Quantity=l["qty"],
                ListPrice=l["list"], UnitPrice=l["unit"], Discount=l["disc"], TotalPrice=l["total"],
                ServiceDate=None, CurrencyIsoCode=cur, CreatedDate=self.ts(stage_dates[min(2, len(path) - 1)]
                                                                           if opp_type == "New Business" else created),
                SystemModstamp=last_mod, IsDeleted=False))

        opp = dict(
            Id=oid, AccountId=acct["Id"], Name=f"{acct['Name']} - {opp_type}{name_suffix}", Type=opp_type,
            StageName=final[0], Probability=final[1], ForecastCategoryName=final[2], Amount=amount,
            CloseDate=close, IsClosed=closed, IsWon=won,
            LeadSource=str(self.rng.choice(["Web", "Outbound", "Partner", "Event", "Referral"]))
            if opp_type == "New Business" else None,
            OwnerId=owner, CurrencyIsoCode=cur, Pricebook2Id=self.pricebook_id if lines else None,
            SyncedQuoteId=synced_quote, HasOpportunityLineItem=bool(lines), CreatedDate=created_ts,
            LastModifiedDate=last_mod, SystemModstamp=last_mod, IsDeleted=False)
        self.rows("opportunity").append(opp)
        return opp, lines

    # ------------------------------------------------------------ orders / contracts
    def make_order(self, acct, opp, lines, start: dt.date, order_type, freq):
        cur = acct["CurrencyIsoCode"]
        oid = self.sfid("801")
        end = add_months(start, 12) - DAY
        activated = start <= self.last_event_day
        created = self.ts(opp["CloseDate"] if opp else start)
        items = []
        for l in lines:
            recurring = self.products[l["code"]]["recurring"]
            iid = self.sfid("802")
            items.append(dict(
                Id=iid, OrderId=oid, Product2Id=self.products[l["code"]]["Id"], PricebookEntryId=l["pbe"],
                QuoteLineItemId=l.get("qlid"), OriginalOrderItemId=l.get("orig_item"), Quantity=l["qty"],
                ListPrice=l["list"], UnitPrice=l["unit"], TotalPrice=money(l["qty"] * l["unit"], cur),
                ServiceDate=start, EndDate=l.get("end", end) if recurring else None, CurrencyIsoCode=cur,
                CreatedDate=created, SystemModstamp=created, IsDeleted=False, _code=l["code"]))
        order = dict(
            Id=oid, OrderNumber=f"{self.seq('order'):08d}", AccountId=acct["Id"],
            OpportunityId=opp["Id"] if opp else None, QuoteId=opp.get("SyncedQuoteId") if opp else None,
            Pricebook2Id=self.pricebook_id, Type=order_type,
            Status="Activated" if activated else "Draft", StatusCode="Activated" if activated else "Draft",
            EffectiveDate=start, EndDate=end, ActivatedDate=self.ts(start) if activated else None,
            IsReductionOrder=False, OriginalOrderId=None, Billing_Frequency__c=freq,
            TotalAmount=money(sum(x["TotalPrice"] for x in items), cur), CurrencyIsoCode=cur,
            CreatedDate=created, LastModifiedDate=self.ts(start) if activated else created,
            SystemModstamp=self.ts(start) if activated else created, IsDeleted=False,
            _items=items, _acct=acct, _cancel=None, _reduction=None, _usage=[])
        self.rows("order").append(order)
        return order

    def run_contract(self, acct, order, depth=0):
        """Lifecycle of one 12-month contract: cancellation, reduction, usage, expansion, renewal."""
        mess = self.cfg["mess"]
        start, end = order["EffectiveDate"], order["EndDate"]
        cur = acct["CurrencyIsoCode"]
        if order["Status"] != "Activated":
            return
        # cancellation (kills the contract)
        if self.p(mess["cancelled_order"]):
            cdate = start + dt.timedelta(days=self.i(5, 40))
            if cdate <= self.last_event_day:
                order.update(Status="Cancelled", StatusCode="Canceled", _cancel=cdate,
                             LastModifiedDate=self.ts(cdate), SystemModstamp=self.ts(cdate))
                return
        # reduction order (mid-term downsell on a seat line)
        seat_items = [x for x in order["_items"] if x["_code"].startswith("SEAT")]
        if seat_items and self.p(mess["reduction_order"]):
            rdate = start + dt.timedelta(days=self.i(90, 270))
            if rdate <= self.last_event_day:
                it = seat_items[0]
                cut = max(1, int(it["Quantity"] * self.u(0.1, 0.4)))
                red = self.make_order(acct, None, [dict(
                    code=it["_code"], qty=-cut, list=it["ListPrice"], unit=it["UnitPrice"],
                    pbe=it["PricebookEntryId"], orig_item=it["Id"], end=end)], rdate, "Reduction",
                    order["Billing_Frequency__c"])
                red.update(IsReductionOrder=True, OriginalOrderId=order["Id"], EndDate=end)
                red["_items"][0]["EndDate"] = end
                order["_reduction"] = (rdate, it["Id"], cut)
                it["_reduced_qty"] = it["Quantity"] - cut
        # consumption usage against the commit
        commit = next((x for x in order["_items"] if x["_code"] == "API-COMMIT"), None)
        if commit:
            fit = float(self.rng.lognormal(0, 0.35))
            m = 0
            while add_months(start, m + 1) - DAY <= self.last_event_day and m < 12:
                ramp = min(1.0, 0.45 + 0.1 * m)
                order["_usage"].append((add_months(start, m), add_months(start, m + 1) - DAY,
                                        round(commit["Quantity"] / 12 * ramp * fit * self.u(0.85, 1.15))))
                m += 1
        acct["won_any"] = True
        # expansion (separate 12-month term; see README: co-terming simplification)
        if order["Type"] in ("New", "Renewal") and self.p(self.cfg["funnel"]["expansion_rate"]):
            c = start + dt.timedelta(days=self.i(45, 240))
            if c <= self.last_event_day and c < end:
                if self.p(0.5) and seat_items:
                    s = seat_items[0]
                    spec = [[s["_code"], max(5, int(s["Quantity"] * self.u(0.1, 0.4))),
                             round(100 * (1 - s["UnitPrice"] / s["ListPrice"]))]]
                else:
                    base = commit["Quantity"] if commit else 50_000
                    spec = [["API-COMMIT", int(round(base * self.u(0.25, 1.0), -4)) or 10_000, 5]]
                opp_acct = self.pick_account(acct)
                opp, lines = self.make_opp(opp_acct, "Expansion", c, self.i(20, 60), spec,
                                           self.cfg["funnel"]["expansion_win_rate"])
                self.book(opp_acct, opp, lines, "Add-On", order["Billing_Frequency__c"], depth + 1)
        # renewal
        rc = end - dt.timedelta(days=self.i(60, 90))
        if rc <= self.last_event_day:
            spec = []
            for x in order["_items"]:
                code = x["_code"]
                if not self.products[code]["recurring"]:
                    continue
                qty = x.get("_reduced_qty", x["Quantity"])
                if code == "API-COMMIT":
                    used = sum(u[2] for u in order["_usage"])
                    factor = self.u(1.1, 1.8) if used > qty * 0.9 else self.u(0.6, 1.0)
                    qty = int(round(qty * factor, -4)) or 10_000
                elif code.startswith("SEAT"):
                    qty = max(1, int(qty * self.u(0.85, 1.3)))
                disc = max(0, round(100 * (1 - x["UnitPrice"] / x["ListPrice"])) - self.i(0, 3))
                spec.append([code, qty, disc])
            if spec:
                opp_acct = self.pick_account(acct)
                opp, lines = self.make_opp(opp_acct, "Renewal", rc, (end - rc).days, spec,
                                           self.cfg["funnel"]["renewal_win_rate"])
                self.book(opp_acct, opp, lines, "Renewal", order["Billing_Frequency__c"], depth + 1,
                          start=end + DAY)

    def pick_account(self, acct):
        """Reps attach new opps to whichever duplicate record they find first."""
        root = next(a for a in self.accounts if a["Id"] == acct["canonical"]) if acct["canonical"] != acct["Id"] else acct
        if root["dup"] is not None and self.p(0.4):
            return root["dup"]
        return root

    def book(self, acct, opp, lines, order_type, freq, depth, start=None):
        if not opp["IsWon"]:
            return None
        mess = self.cfg["mess"]
        if self.p(mess["won_without_order"]):
            opp["_no_order"] = True
            opp["_billed_anyway"] = self.p(mess["won_without_order_billed"])
            opp["_lines"] = lines
            acct["won_any"] = True
            return None
        start = start or opp["CloseDate"] + dt.timedelta(days=self.i(0, 21))
        order = self.make_order(acct, opp, lines, start, order_type, freq)
        if depth < 8:
            self.run_contract(acct, order, depth)
        return order

    def build_pipeline(self):
        f = self.cfg["funnel"]
        span = (self.last_event_day - self.start).days
        for a in [a for a in self.accounts if a["canonical"] == a["Id"]]:
            # growth-weighted first touch: later months have more activity
            first = self.start + dt.timedelta(days=int(span * (self.rng.random() ** 0.7)))
            first = max(first, a["CreatedDate"].date())
            c = first
            while c <= self.last_event_day:
                acct = self.pick_account(a)
                opp, lines = self.make_opp(acct, "New Business", c, self.i(*f["sales_cycle_days"]),
                                           self.nb_lines(a["segment"]), f["new_biz_win_rate"])
                if opp["IsWon"]:
                    freq = str(self.rng.choice(["Annual", "Quarterly", "Monthly"], p=[0.55, 0.3, 0.15]))
                    self.book(acct, opp, lines, "New", freq, 0)
                    break
                if not opp["IsClosed"] or not self.p(f["retry_after_loss_rate"]):
                    break
                c = opp["CloseDate"] + dt.timedelta(days=self.i(90, 240))

        # soft deletes (open/lost only; children cascade)
        for o in self.rows("opportunity"):
            if not o["IsWon"] and self.p(self.cfg["mess"]["deleted_opportunity"]):
                o["IsDeleted"] = True
        deleted = {o["Id"] for o in self.rows("opportunity") if o["IsDeleted"]}
        dq = set()
        for tbl in ("opportunity_line_item", "opportunity_history", "quote"):
            for r in self.rows(tbl):
                if r["OpportunityId"] in deleted:
                    r["IsDeleted"] = True
                    if tbl == "quote":
                        dq.add(r["Id"])
        for r in self.rows("quote_line_item"):
            if r["QuoteId"] in dq:
                r["IsDeleted"] = True

    # ------------------------------------------------------------ billing (Stripe-shaped)
    def customer_for(self, acct):
        root = acct["canonical"]
        if root not in self.customers:
            a = next(x for x in self.accounts if x["Id"] == root)
            cid = self.stripe_id("cus_")
            t = self.ts(max(acct["CreatedDate"].date(), self.start))
            self.customers[root] = cid
            self.rows("customer").append(dict(
                id=cid, name=a["Name"], email=f"ap@{a['Website'].replace('www.', '')}",
                currency=a["CurrencyIsoCode"].lower(), metadata_salesforce_account_id=acct["Id"],
                created=t, delinquent=False, _updated=t))
        return self.customers[root]

    def new_invoice(self, cust, cur, created: dt.datetime, period_start, period_end, reason, order_id, lines):
        """lines: list of (description, qty, unit_amount_major, amount_major, product_code, order_item_id, proration)"""
        if created > self.billing_sync:
            return None
        iid = self.stripe_id("in_")
        total = sum(minor(l[3], cur) for l in lines)
        true_order_id = order_id
        if order_id and self.p(self.cfg["mess"]["invoice_missing_order_ref"]):
            order_id = None
        inv = dict(id=iid, customer_id=cust, number=f"{cust[4:12].upper()}-{self.seq('inv_' + cust):04d}",
                   status="open", billing_reason=reason, collection_method="send_invoice",
                   currency=cur.lower(), subtotal=total, total=total, amount_due=max(total, 0), amount_paid=0,
                   amount_remaining=max(total, 0), created=created, period_start=period_start,
                   period_end=period_end, due_date=created + dt.timedelta(days=30),
                   status_transitions_paid_at=None, metadata_salesforce_order_id=order_id,
                   _true_order_id=true_order_id, _updated=created)
        self.rows("invoice").append(inv)
        for desc, qty, unit, amt, code, item_id, prorate in lines:
            self.rows("invoice_line_item").append(dict(
                id=self.stripe_id("il_"), invoice_id=iid, type="subscription" if code != "SVC-ONB" else "invoiceitem",
                description=desc, quantity=qty, unit_amount_decimal=round(unit * (1 if cur == "JPY" else 100), 4),
                amount=minor(amt, cur), currency=cur.lower(), period_start=period_start, period_end=period_end,
                proration=prorate, metadata_product_code=code, metadata_salesforce_order_item_id=item_id,
                _updated=created))
        if total <= 0:
            inv.update(status="paid", amount_due=0, amount_remaining=0, status_transitions_paid_at=created)
        return inv

    def build_billing(self):
        self.customers = {}
        mess = self.cfg["mess"]
        step = {"Annual": 12, "Quarterly": 3, "Monthly": 1}
        for o in self.rows("order"):
            if o["IsReductionOrder"] or o["Status"] == "Draft":
                continue
            acct, cur = o["_acct"], o["CurrencyIsoCode"]
            cust = self.customer_for(acct)
            n = step[o["Billing_Frequency__c"]]
            k, first = 0, True
            while k < 12:
                ps = add_months(o["EffectiveDate"], k)
                pe = add_months(o["EffectiveDate"], k + n) - DAY
                if ps > self.last_event_day or (o["_cancel"] and ps >= o["_cancel"]):
                    break
                lines = []
                for it in o["_items"]:
                    code = it["_code"]
                    qty = it["Quantity"]
                    if o["_reduction"] and it["Id"] == o["_reduction"][1] and ps >= o["_reduction"][0]:
                        qty = it["_reduced_qty"]
                    if self.products[code]["recurring"]:
                        amt = qty * it["UnitPrice"] * n / 12
                        lines.append((f"{self.products[code]['name']} ({ps:%b %Y})", qty, it["UnitPrice"] * n / 12,
                                      amt, code, it["Id"], False))
                    elif first:
                        lines.append((self.products[code]["name"], qty, it["UnitPrice"], qty * it["UnitPrice"],
                                      code, it["Id"], False))
                inv = self.new_invoice(cust, cur, self.ts(ps, 6, 9), ps, pe,
                                       "subscription_create" if first else "subscription_cycle", o["Id"], lines)
                if inv and o["_cancel"]:
                    inv.update(status="void", amount_remaining=0, _updated=self.ts(o["_cancel"]))
                    inv["_void"] = True
                first = False
                k += n
            # reduction credit for the unused part of the already-billed period
            if o["_reduction"]:
                rdate, item_id, cut = o["_reduction"]
                it = next(x for x in o["_items"] if x["Id"] == item_id)
                k0 = ((rdate.year - o["EffectiveDate"].year) * 12 + rdate.month - o["EffectiveDate"].month) // n * n
                while k0 > 0 and add_months(o["EffectiveDate"], k0) > rdate:
                    k0 -= n
                ps, pe = add_months(o["EffectiveDate"], k0), add_months(o["EffectiveDate"], k0 + n) - DAY
                frac = (pe - rdate).days / max(1, (pe - ps).days + 1)
                red = next(r for r in self.rows("order") if r["OriginalOrderId"] == o["Id"])
                credit = -cut * it["UnitPrice"] * n / 12 * frac
                if abs(credit) > 0:
                    self.new_invoice(cust, cur, self.ts(rdate, 9, 12), rdate, pe, "subscription_update", red["Id"],
                                     [(f"Unused time on {cut} x {self.products[it['_code']]['name']}", -cut,
                                       it["UnitPrice"] * n / 12 * frac, credit, it["_code"], red["_items"][0]["Id"],
                                       True)])
            # consumption: usage summaries + monthly overage in arrears once the commit is burned
            commit = next((x for x in o["_items"] if x["_code"] == "API-COMMIT"), None)
            if commit and not o["_cancel"]:
                cum, over_unit = 0, self.pbe[("API-OVER", cur)][1]
                for ps, pe, used in o["_usage"]:
                    loaded = self.ts(pe + DAY, 0, 3)
                    if loaded > self.billing_sync:
                        break
                    self.rows("usage_record_summary").append(dict(
                        id=self.stripe_id("sis_"), customer_id=cust, metadata_salesforce_order_item_id=commit["Id"],
                        period_start=ps, period_end=pe, total_usage=used, _updated=loaded))
                    over = max(0, cum + used - commit["Quantity"]) - max(0, cum - commit["Quantity"])
                    cum += used
                    if over > 0:
                        self.new_invoice(cust, cur, self.ts(pe + DAY, 6, 9), ps, pe, "subscription_cycle", o["Id"],
                                         [(f"Usage overage {ps:%b %Y}", over, over_unit, over * over_unit,
                                           "API-OVER", commit["Id"], False)])

        # Closed Won without an Order that billing invoiced anyway (no order ref possible)
        for opp in self.rows("opportunity"):
            if opp.get("_no_order") and opp.get("_billed_anyway") and opp["_lines"]:
                acct = next(a for a in self.accounts if a["Id"] == opp["AccountId"])
                cur = opp["CurrencyIsoCode"]
                d = opp["CloseDate"] + dt.timedelta(days=self.i(3, 20))
                if d > self.last_event_day:
                    continue
                self.new_invoice(self.customer_for(acct), cur, self.ts(d, 6, 9), d, add_months(d, 12) - DAY,
                                 "manual", None, [(self.products[l["code"]]["name"], l["qty"], l["unit"],
                                                   l["qty"] * l["unit"], l["code"], None, False)
                                                  for l in opp["_lines"]])

        self.build_payments()

    def build_payments(self):
        profile = {}
        for inv in self.rows("invoice"):
            if inv.get("_void") or inv["amount_due"] <= 0:
                continue
            cust = inv["customer_id"]
            if cust not in profile:
                profile[cust] = str(self.rng.choice(["good", "slow", "bad"], p=[0.8, 0.15, 0.05]))
            prof = profile[cust]
            due, cur = inv["amount_due"], inv["currency"]
            if prof == "bad" and self.p(0.4):
                attempts = []
            else:
                days = {"good": (0, 25), "slow": (20, 75), "bad": (40, 150)}[prof]
                pay = inv["created"] + dt.timedelta(days=self.i(*days), hours=self.i(0, 8))
                attempts = []
                if self.p(self.cfg["mess"]["failed_then_retried"]):
                    attempts.append((pay, 0, "failed"))
                    pay = pay + dt.timedelta(days=self.i(3, 10))
                if self.p(self.cfg["mess"]["partial_payment"]):
                    part = int(due * self.u(0.3, 0.8))
                    attempts.append((pay, part, "succeeded"))
                    if self.p(0.5):
                        attempts.append((pay + dt.timedelta(days=self.i(15, 45)), due - part, "succeeded"))
                else:
                    attempts.append((pay, due, "succeeded"))
            paid, last = 0, inv["created"]
            for t, amt, status in attempts:
                if t > self.billing_sync:
                    continue
                self.rows("charge").append(dict(
                    id=self.stripe_id("ch_"), invoice_id=inv["id"], customer_id=cust,
                    amount=amt if status == "succeeded" else due, amount_refunded=0, currency=cur, status=status,
                    paid=status == "succeeded", failure_code=None if status == "succeeded" else str(
                        self.rng.choice(["card_declined", "insufficient_funds", "expired_card"])),
                    payment_method_type="card" if due < 1_000_000 else "ach_credit_transfer",
                    created=t, _updated=t))
                if status == "succeeded":
                    paid += amt
                last = max(last, t)
            inv.update(amount_paid=paid, amount_remaining=due - paid, _updated=last)
            if paid >= due:
                inv.update(status="paid", status_transitions_paid_at=last)
            elif prof == "bad" and inv["created"] < self.billing_sync - dt.timedelta(days=120):
                inv.update(status="uncollectible", _updated=inv["created"] + dt.timedelta(days=120))

    # ------------------------------------------------------------ load metadata + write
    def finalize_accounts(self):
        for a in self.accounts:
            a["Type"] = "Customer" if a["won_any"] else "Prospect"
        for a in self.accounts:
            if a["canonical"] != a["Id"]:
                root = next(x for x in self.accounts if x["Id"] == a["canonical"])
                a["Type"] = root["Type"] if self.p(0.5) else "Prospect"  # dup record drifts
        for a in self.accounts:
            t = a["CreatedDate"]
            self.rows("account").append(dict(
                Id=a["Id"], Name=a["Name"], Type=a["Type"], Industry=a["Industry"], Website=a["Website"],
                NumberOfEmployees=a["NumberOfEmployees"], BillingCountry=a["BillingCountry"],
                BillingState=a["BillingState"], CurrencyIsoCode=a["CurrencyIsoCode"], OwnerId=a["OwnerId"],
                CreatedDate=t, LastModifiedDate=t, SystemModstamp=t, IsDeleted=False,
                ParentId=a.get("ParentId")))

    def assign_loaded_at(self):
        late = self.cfg["mess"]["late_arriving"]
        sf_tables = ["user", "dated_conversion_rate", "product2", "pricebook2", "pricebook_entry", "account",
                     "opportunity", "opportunity_history", "opportunity_line_item", "quote", "quote_line_item",
                     "order", "order_item"]
        for o in self.rows("order"):
            for it in o["_items"]:
                self.rows("order_item").append(it)
        # Preserve the historical rng sequence (including late-arrival draws) before any new draws.
        for tbl in sf_tables + ["customer", "invoice", "invoice_line_item", "charge", "usage_record_summary"]:
            sync = self.sf_sync if tbl in sf_tables else self.billing_sync
            for r in self.rows(tbl):
                mod = r.get("SystemModstamp", r.get("_updated"))
                if isinstance(mod, dt.date) and not isinstance(mod, dt.datetime):
                    mod = dt.datetime.combine(mod, dt.time())
                t = mod + dt.timedelta(minutes=self.i(2, 50))
                r["_late_arrival"] = None
                if tbl in ("opportunity", "order", "order_item", "invoice", "charge") and \
                        mod < sync - dt.timedelta(days=21) and self.p(late):
                    t = mod + dt.timedelta(days=self.i(3, 20), minutes=self.i(0, 600))
                    r["_late_arrival"] = t
        self.build_connector_syncs()
        self.touch_open_opportunities()
        for tbl in sf_tables + ["customer", "invoice", "invoice_line_item", "charge", "usage_record_summary"]:
            anchor = self.sf_sync if tbl in sf_tables else self.billing_sync
            for r in self.rows(tbl):
                if r.get("_same_day_touch"):
                    event = r["SystemModstamp"]
                elif r.get("_late_arrival") is not None:
                    event = r["_late_arrival"]
                else:
                    event = r.get("SystemModstamp", r.get("_updated"))
                    if isinstance(event, dt.date) and not isinstance(event, dt.datetime):
                        event = dt.datetime.combine(event, dt.time())
                r["_loaded_at"] = self.snap_to_sync(anchor, event)

    def snap_to_sync(self, last_success: dt.datetime, event_time: dt.datetime) -> dt.datetime:
        """First successful hourly sync_end at or after event_time, never past last_success."""
        if event_time >= last_success:
            return last_success
        hours_back = int((last_success - event_time).total_seconds() // 3600)
        return last_success - dt.timedelta(hours=hours_back)

    def _sync_ends(self, last_success: dt.datetime) -> list[dt.datetime]:
        window_start = self.now - dt.timedelta(days=14)
        ends: list[dt.datetime] = []
        end = last_success
        while end >= window_start:
            ends.append(end)
            end -= dt.timedelta(hours=1)
        ends.reverse()
        return ends

    def build_connector_syncs(self):
        """Hourly Fivetran-style sync log for the 14 days before now. rows_updated draws are new rng."""
        duration = dt.timedelta(minutes=4)
        for end in self._sync_ends(self.sf_sync):
            self.rows("connector_sync").append(dict(
                connector_id="salesforce", sync_start=end - duration, sync_end=end,
                status="SUCCESSFUL", rows_updated=self.i(0, 20000)))
        for end in self._sync_ends(self.billing_sync):
            self.rows("connector_sync").append(dict(
                connector_id="stripe", sync_start=end - duration, sync_end=end,
                status="SUCCESSFUL", rows_updated=self.i(0, 20000)))
        end = self.billing_sync + dt.timedelta(hours=1)
        while end <= self.now:
            self.rows("connector_sync").append(dict(
                connector_id="stripe", sync_start=end - duration, sync_end=end,
                status="FAILURE_WITH_TASK", rows_updated=0))
            end += dt.timedelta(hours=1)

    def touch_open_opportunities(self):
        """Field edits on open opps in the last 8h. No OpportunityHistory row (NextStep-style)."""
        for o in self.rows("opportunity"):
            if o["IsDeleted"] or o["IsClosed"]:
                continue
            if not self.p(0.05):
                continue
            bumped = self.sf_sync - dt.timedelta(seconds=self.i(0, 8 * 3600))
            o["LastModifiedDate"] = bumped
            o["SystemModstamp"] = bumped
            o["_same_day_touch"] = True

    # ------------------------------------------------------------ hard dedup cases
    # Drawn only after assign_loaded_at, so every earlier rng call stays put.
    # New account rows are appended. About five subsidiaries also get one
    # Closed Won opportunity and order, appended to those tables.
    def add_hard_dedup_cases(self):
        eligible = [a for a in self.accounts
                    if a["canonical"] == a["Id"]
                    and a["CreatedDate"].date() <= self.last_event_day - dt.timedelta(days=90)]
        assert len(eligible) >= 60, "not enough aged canonical accounts for hard dedup cases"
        picked = [eligible[int(i)] for i in self.rng.permutation(len(eligible))[:60]]
        collisions = [self._collision_account(parent) for parent in picked[0:15]]
        subsidiaries = [self._subsidiary_account(parent, i) for i, parent in enumerate(picked[15:30])]
        typos = [self._typo_account(parent, i) for i, parent in enumerate(picked[30:45])]
        suffixes = [self._suffix_url_account(parent, i) for i, parent in enumerate(picked[45:60])]
        del collisions, typos, suffixes
        for idx in self.rng.choice(len(subsidiaries), size=5, replace=False):
            self._book_subsidiary(subsidiaries[int(idx)])

    def _later_than(self, created: dt.datetime) -> dt.datetime:
        nxt = created + dt.timedelta(days=self.i(21, 240))
        cap = dt.datetime.combine(self.last_event_day, dt.time(17))
        if nxt > cap:
            nxt = created + dt.timedelta(days=1, hours=2)
        if nxt <= created:
            nxt = created + dt.timedelta(hours=2)
        return min(nxt, cap)

    def _spawn_account(self, parent, *, name, website, country, currency, canonical, case_type,
                       parent_id, billing_state=None):
        created = self._later_than(parent["CreatedDate"])
        owner = str(self.rng.choice(self.reps))
        a = dict(
            Id=self.sfid("001"), Name=name, base=parent["base"], Website=website,
            Industry=parent["Industry"], NumberOfEmployees=None, segment=parent["segment"],
            BillingCountry=country, BillingState=billing_state, CurrencyIsoCode=currency,
            OwnerId=owner, CreatedDate=created, dup=None, canonical=canonical,
            last_touch=created, won_any=False, active_contracts=0, case_type=case_type,
            ParentId=parent_id, Type="Prospect")
        if canonical is None:
            a["canonical"] = a["Id"]
        self.accounts.append(a)
        self._append_account_row(a)
        return a

    def _append_account_row(self, a):
        t = a["CreatedDate"]
        row = dict(
            Id=a["Id"], Name=a["Name"], Type=a["Type"], Industry=a["Industry"], Website=a["Website"],
            NumberOfEmployees=a["NumberOfEmployees"], BillingCountry=a["BillingCountry"],
            BillingState=a["BillingState"], CurrencyIsoCode=a["CurrencyIsoCode"], OwnerId=a["OwnerId"],
            CreatedDate=t, LastModifiedDate=t, SystemModstamp=t, IsDeleted=False, ParentId=a.get("ParentId"))
        row["_loaded_at"] = self.snap_to_sync(self.sf_sync, t)
        self.rows("account").append(row)

    def _collision_account(self, parent):
        places = [(c, cur) for cur, spec in self.curs.items() for c in spec["countries"] if c != parent["BillingCountry"]]
        country, currency = places[self.i(0, len(places) - 1)]
        state = str(self.rng.choice(US_STATES)) if country == "US" else None
        suffix = {"DE": "GmbH", "JP": "K.K.", "GB": "Ltd.", "IE": "Ltd."}.get(country, "Inc.")
        if parent["Name"].endswith(suffix):
            suffix = "LLC" if suffix != "LLC" else "Corp."
        name = f"{parent['base']} {suffix}".strip()
        slug = "".join(ch for ch in parent["base"].lower() if ch.isalnum())
        website = f"www.{slug}global.com"
        assert _name_key(name) == _name_key(parent["Name"]), (name, parent["Name"])
        assert _domain_key(website) != _domain_key(parent["Website"])
        return self._spawn_account(
            parent, name=name, website=website, country=country, currency=currency,
            canonical=None, case_type="collision", parent_id=None, billing_state=state)

    def _subsidiary_account(self, parent, i: int):
        if i % 2 == 0:
            name, country, currency = f"{parent['base']} Europe GmbH", "DE", "EUR"
        else:
            name, country, currency = f"{parent['base']} Japan K.K.", "JP", "JPY"
        assert _domain_key(parent["Website"])
        assert _name_key(name) != _name_key(parent["Name"])
        return self._spawn_account(
            parent, name=name, website=parent["Website"], country=country, currency=currency,
            canonical=None, case_type="subsidiary", parent_id=parent["Id"])

    def _typo_account(self, parent, i: int):
        name = _drop_first_vowel(parent["base"]) if i % 2 == 0 else f"{parent['base']} Intl"
        assert _name_key(name) and _name_key(name) != _name_key(parent["Name"])
        return self._spawn_account(
            parent, name=name, website=None, country=parent["BillingCountry"],
            currency=parent["CurrencyIsoCode"], canonical=parent["Id"], case_type="typo",
            parent_id=None, billing_state=parent["BillingState"])

    def _suffix_url_account(self, parent, i: int):
        suffix = next(s for s in ("Inc.", "LLC", "Ltd.", "GmbH", "Corp.", "Holdings")
                      if not parent["Name"].endswith(s))
        domain = _domain_key(parent["Website"])
        website = f"https://{domain}/contact" if i % 2 == 0 else f"https://{domain}/"
        assert _domain_key(website) == domain
        return self._spawn_account(
            parent, name=f"{parent['base']} {suffix}".strip(), website=website,
            country=parent["BillingCountry"], currency=parent["CurrencyIsoCode"],
            canonical=parent["Id"], case_type="suffix_url", parent_id=None,
            billing_state=parent["BillingState"])

    def _book_subsidiary(self, acct):
        """One active Closed Won contract on the subsidiary, not the parent."""
        created_date = acct["CreatedDate"].date()
        window_end = self.last_event_day - dt.timedelta(days=30)
        window_start = max(created_date + dt.timedelta(days=1), self.last_event_day - dt.timedelta(days=300))
        if window_start > window_end:
            window_start = window_end
        start = window_start + dt.timedelta(days=self.i(0, max((window_end - window_start).days, 0)))
        cur = acct["CurrencyIsoCode"]
        code = "SEAT-TEAM"
        eid, list_price = self.pbe[(code, cur)]
        qty, disc = self.i(10, 40), self.i(0, 10)
        unit = round(list_price * (1 - disc / 100), dp(cur))
        lines = [dict(code=code, qty=qty, disc=disc, list=list_price, unit=unit, pbe=eid,
                      total=money(qty * unit, cur))]
        created_ts = self.ts(max(created_date, start - dt.timedelta(days=20)))
        close_ts = self.ts(start)
        oid = self.sfid("006")
        amount = lines[0]["total"]
        self.rows("opportunity_history").append(dict(
            Id=self.sfid("008"), OpportunityId=oid, StageName="Closed Won", Amount=amount,
            ExpectedRevenue=amount, CloseDate=start, Probability=100, ForecastCategory="Closed",
            CreatedById=acct["OwnerId"], CreatedDate=close_ts, SystemModstamp=close_ts, IsDeleted=False,
            _loaded_at=self.snap_to_sync(self.sf_sync, close_ts)))
        self.rows("opportunity_line_item").append(dict(
            Id=self.sfid("00k"), OpportunityId=oid, PricebookEntryId=eid,
            Product2Id=self.products[code]["Id"], ProductCode=code, Quantity=qty,
            ListPrice=list_price, UnitPrice=unit, Discount=disc, TotalPrice=amount,
            ServiceDate=None, CurrencyIsoCode=cur, CreatedDate=created_ts, SystemModstamp=close_ts,
            IsDeleted=False, _loaded_at=self.snap_to_sync(self.sf_sync, close_ts)))
        opp = dict(
            Id=oid, AccountId=acct["Id"], Name=f"{acct['Name']} - New Business", Type="New Business",
            StageName="Closed Won", Probability=100, ForecastCategoryName="Closed", Amount=amount,
            CloseDate=start, IsClosed=True, IsWon=True, LeadSource="Partner", OwnerId=acct["OwnerId"],
            CurrencyIsoCode=cur, Pricebook2Id=self.pricebook_id, SyncedQuoteId=None,
            HasOpportunityLineItem=True, CreatedDate=created_ts, LastModifiedDate=close_ts,
            SystemModstamp=close_ts, IsDeleted=False,
            _loaded_at=self.snap_to_sync(self.sf_sync, close_ts))
        self.rows("opportunity").append(opp)
        order = self.make_order(acct, opp, lines, start, "New", "Annual")
        order["_loaded_at"] = self.snap_to_sync(self.sf_sync, order["SystemModstamp"])
        for it in order["_items"]:
            it["_loaded_at"] = self.snap_to_sync(self.sf_sync, it["SystemModstamp"])
            self.rows("order_item").append(it)
        acct["Type"] = "Customer"
        acct["won_any"] = True
        for row in self.rows("account"):
            if row["Id"] == acct["Id"]:
                row["Type"] = "Customer"

    def write(self, out: Path):
        systems = {"salesforce": ["user", "dated_conversion_rate", "product2", "pricebook2", "pricebook_entry",
                                  "account", "opportunity", "opportunity_history", "opportunity_line_item",
                                  "quote", "quote_line_item", "order", "order_item"],
                   "billing": ["customer", "invoice", "invoice_line_item", "charge", "usage_record_summary"],
                   "fivetran_log": ["connector_sync"]}
        summary = []
        for system, tables in systems.items():
            (out / system).mkdir(parents=True, exist_ok=True)
            for tbl in tables:
                rows = [{k: fmt(v) if isinstance(v, (dt.date, dt.datetime)) else v
                         for k, v in r.items() if not k.startswith("_") or k == "_loaded_at"}
                        for r in self.rows(tbl)]
                df = pd.DataFrame(rows)
                df.to_csv(out / system / f"{tbl}.csv", index=False)
                summary.append((system, tbl, len(df)))
        self.write_truth(out.parent / "truth")
        return summary

    def write_truth(self, truth: Path):
        """Evaluation keys. No randomness; private fields only, so raw CSVs stay unchanged."""
        truth.mkdir(parents=True, exist_ok=True)
        accounts = pd.DataFrame(
            [{"account_id": a["Id"], "true_master_account_id": a["canonical"], "case_type": a["case_type"]}
             for a in self.accounts],
            columns=["account_id", "true_master_account_id", "case_type"],
        )
        invoices = pd.DataFrame(
            [{"invoice_id": r["id"], "true_order_id": r.get("_true_order_id")} for r in self.rows("invoice")],
            columns=["invoice_id", "true_order_id"],
        )
        accounts.to_csv(truth / "account_duplicates.csv", index=False)
        invoices.to_csv(truth / "invoice_order.csv", index=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--as-of", help="YYYY-MM-DD; pins 'now' to 06:00 UTC that day for byte-identical output")
    ap.add_argument("--config", default=str(ROOT / "generator" / "config.yaml"))
    ap.add_argument("--out", default=str(ROOT / "data" / "raw"))
    args = ap.parse_args()
    cfg = yaml.safe_load(open(args.config))
    if args.as_of:
        as_of = dt.date.fromisoformat(args.as_of)
        now = dt.datetime.combine(as_of, dt.time(6))
    else:
        now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None, second=0, microsecond=0)
        as_of = now.date()
    g = Gen(cfg, as_of, now)
    g.build_reference()
    g.build_accounts()
    g.build_pipeline()
    g.build_billing()
    g.finalize_accounts()
    g.assign_loaded_at()
    g.add_hard_dedup_cases()
    summary = g.write(Path(args.out))
    print(f"as_of={as_of} now={now:%Y-%m-%d %H:%M} salesforce_sync={g.sf_sync:%Y-%m-%d %H:%M} "
          f"billing_sync={g.billing_sync:%Y-%m-%d %H:%M}")
    for system, tbl, n in summary:
        print(f"  {system:<11}{tbl:<24}{n:>7,}")


if __name__ == "__main__":
    main()
