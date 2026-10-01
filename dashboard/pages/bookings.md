---
title: Bookings vs Billings
---

```sql as_of
select as_of_date
from gtm.connector_freshness
limit 1
```

```sql salesforce
select connector, last_successful_sync, age_hours, status
from gtm.connector_freshness
where connector_id = 'salesforce'
```

```sql stripe
select connector, last_successful_sync, age_hours, status
from gtm.connector_freshness
where connector_id = 'stripe'
```

Data as of <Value data={as_of} column=as_of_date />

{#if salesforce[0].status == 'PASS'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · PASS</span>
{:else if salesforce[0].status == 'WARN'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · WARN</span>
{:else}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · ERROR</span>
{/if}
{#if stripe[0].status == 'PASS'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · PASS</span>
{:else if stripe[0].status == 'WARN'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · WARN</span>
{:else}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · ERROR</span>
{/if}

```sql monthly
select cast(date_trunc('month', booking_date) as date) as month, sum(bookings_acv_usd) as usd, 'Bookings ACV' as measure
from gtm.bookings
group by 1
union all
select cast(date_trunc('month', invoice_date) as date), sum(billed_usd), 'Billings'
from gtm.billings
group by 1
order by month
```

```sql latest_compare
with last_month as (
    select max(cast(date_trunc('month', invoice_date) as date)) as month
    from gtm.billings
)
select
    (select sum(bookings_acv_usd) from gtm.bookings where cast(date_trunc('month', booking_date) as date) = (select month from last_month)) as bookings_usd,
    (select sum(billed_usd) from gtm.billings where cast(date_trunc('month', invoice_date) as date) = (select month from last_month)) as billings_usd
```

## Latest month bookings ACV were <Value data={latest_compare} column=bookings_usd fmt=usd1m /> against <Value data={latest_compare} column=billings_usd fmt=usd1m /> of billings

<BarChart
    data={monthly}
    x=month
    y=usd
    series=measure
    seriesOrder={['Bookings ACV', 'Billings']}
    type=grouped
    yFmt=usd1m
    xFmt=shortdate
/>

```sql status_counts
select
    status,
    count(*) as orders,
    sum(contract_value_usd) as contract_value_usd,
    sum(variance_usd) as variance_usd
from gtm.bookings_to_billings
group by status
order by contract_value_usd desc
```

```sql status_leader
select status, count(*) as orders, sum(contract_value_usd) as contract_value_usd
from gtm.bookings_to_billings
group by status
order by orders desc
limit 1
```

## <Value data={status_leader} column=orders fmt=num0 /> orders are <Value data={status_leader} column=status />, <Value data={status_leader} column=contract_value_usd fmt=usd1m /> of contract value

<DataTable data={status_counts} rows=10>
    <Column id=status title="Status"/>
    <Column id=orders title="Orders" fmt=num0/>
    <Column id=contract_value_usd title="Contract value" fmt=usd1m/>
    <Column id=variance_usd title="Variance" fmt=usd1m/>
</DataTable>

```sql exceptions
select
    case exception_type
        when 'closed_won_without_order' then 'Won without order'
        when 'billed_without_order' then 'Billed without order'
        when 'closed_won_amount_line_mismatch' then 'Amount ≠ lines'
    end as exception,
    entity_id,
    age_days,
    usd_at_stake
from gtm.exceptions
order by usd_at_stake desc nulls last
```

```sql exception_total
select count(*) as items, sum(usd_at_stake) as usd_at_stake
from gtm.exceptions
```

## <Value data={exception_total} column=items fmt=num0 /> quote-to-cash exceptions, <Value data={exception_total} column=usd_at_stake fmt=usd1m /> at stake

<DataTable data={exceptions} rows=20 search=true>
    <Column id=exception title="Exception"/>
    <Column id=entity_id title="Id"/>
    <Column id=age_days title="Age (days)" fmt=num0/>
    <Column id=usd_at_stake title="USD at stake" fmt=usd0k/>
</DataTable>
