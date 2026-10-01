---
title: Bookings to billings
hide_title: true
---

```sql periods
select distinct month_key as value, strftime(month_end, '%b %Y') as label
from gtm.finance_month
where segment = 'All' and currency = 'All'
order by value
```

```sql currencies_list
select 'All' as value
union all
select distinct currency as value
from gtm.finance_month
where currency != 'All'
order by value
```

```sql kpi
select *
from gtm.finance_month
where month_key = '${inputs.period.value}'
  and segment = '${inputs.segment.value}'
  and currency = '${inputs.currency.value}'
```

```sql currency_rows
select *
from gtm.finance_currency
where month_key = '${inputs.period.value}'
  and segment = '${inputs.segment.value}'
  and ('${inputs.currency.value}' = 'All' or currency = '${inputs.currency.value}')
order by is_total, billed_usd desc
```

```sql aging
select *
from gtm.finance_aging
where segment = '${inputs.segment.value}'
  and currency = '${inputs.currency.value}'
  and month_key >= '2026-03-01'
  and month_key <= '${inputs.period.value}'
order by month_key
```

```sql burn
select *
from gtm.commit_slice
where segment = '${inputs.segment.value}'
  and currency = '${inputs.currency.value}'
  and month_key <= '${inputs.period.value}'
order by month_key
```

```sql orders
select *
from gtm.booked_not_billed
where strftime(month_end, '%Y-%m-%d') = '${inputs.period.value}'
  and ('${inputs.segment.value}' = 'All' or segment = '${inputs.segment.value}')
order by amount_usd desc
```

```sql freshness
select * from gtm.connector_freshness order by connector_id
```

<UrlSync keys="period,currency,segment" defaults="period:2026-08-31,currency:All,segment:All" primary="period" />

<FinanceView kpi={kpi} currencies={currency_rows} {aging} {burn} {orders} {freshness}>
  <div slot="controls">
    <Dropdown name="period" title="Period" data={periods} defaultValue="2026-08-31" />
    <Dropdown name="currency" title="Currency" data={currencies_list} defaultValue="All" />
    <Dropdown name="segment" title="Segment" defaultValue="All">
      <DropdownOption value="All" valueLabel="All" />
      <DropdownOption value="Enterprise" valueLabel="Enterprise" />
      <DropdownOption value="Mid-market" valueLabel="Mid-market" />
      <DropdownOption value="SMB" valueLabel="SMB" />
      <DropdownOption value="Startups" valueLabel="Startups" />
      <DropdownOption value="Public sector" valueLabel="Public sector" />
    </Dropdown>
  </div>
</FinanceView>
