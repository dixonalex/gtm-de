---
title: Overview
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

```sql arr_kpi
with months as (
    select
        month_end,
        sum(committed_arr_usd) as committed_arr_usd,
        sum(committed_arr_usd) - sum(opening_arr_usd) as net_new_arr_usd,
        row_number() over (order by month_end desc) as rn
    from gtm.arr_monthly
    group by month_end
)
select
    strftime(latest.month_end, '%b %Y') as month_label,
    latest.committed_arr_usd,
    latest.committed_arr_usd - prior.committed_arr_usd as mom_delta_usd,
    latest.net_new_arr_usd
from months latest
left join months prior on prior.rn = 2
where latest.rn = 1
```

```sql pipeline_kpi
select
    strftime(month_end, '%b %Y') as month_label,
    sum(amount_usd) as open_pipeline_usd
from gtm.pipeline
where month_end = (select max(month_end) from gtm.pipeline)
group by month_end
```

```sql billings_kpi
with closed as (
    select max(month_end) as month_end from gtm.arr_monthly
)
select
    strftime(closed.month_end, '%b %Y') as month_label,
    sum(b.billed_usd) as billings_usd
from gtm.billings b
cross join closed
where date_trunc('month', b.invoice_date) = date_trunc('month', closed.month_end)
group by closed.month_end
```

```sql mtd
with closed as (
    select max(month_end) as month_end from gtm.arr_monthly
),
open_month as (
    select max(cast(date_trunc('month', invoice_date) as date)) as month
    from gtm.billings
    where cast(date_trunc('month', invoice_date) as date) > (select date_trunc('month', month_end) from closed)
)
select
    strftime(open_month.month, '%b %Y') as month_label,
    (
        select sum(bookings_acv_usd)
        from gtm.bookings
        where cast(date_trunc('month', booking_date) as date) = open_month.month
    ) as bookings_usd,
    (
        select sum(billed_usd)
        from gtm.billings
        where cast(date_trunc('month', invoice_date) as date) = open_month.month
    ) as billings_usd
from open_month
where open_month.month is not null
```

```sql dq_kpi
select
    count(*) filter (where status = 'warn') as warn_count,
    count(*) filter (where status in ('fail', 'error')) as error_count
from gtm.test_results
```

<BigValue
    data={arr_kpi}
    value=committed_arr_usd
    title={"Committed ARR · " + arr_kpi[0].month_label}
    fmt=usd1m
    comparison=mom_delta_usd
    comparisonFmt=usd1m
    comparisonTitle="vs prior month"
    neutralMin=-1000000000000
    neutralMax=1000000000000
    link="/arr"
/>

<BigValue
    data={arr_kpi}
    value=net_new_arr_usd
    title={"Net new ARR · " + arr_kpi[0].month_label}
    fmt=usd1m
    link="/arr"
/>

<BigValue
    data={pipeline_kpi}
    value=open_pipeline_usd
    title={"Open pipeline · " + pipeline_kpi[0].month_label}
    fmt=usd1m
    link="/pipeline"
/>

<BigValue
    data={billings_kpi}
    value=billings_usd
    title={"Billings · " + billings_kpi[0].month_label}
    fmt=usd1m
    link="/bookings"
/>

<BigValue
    data={dq_kpi}
    value=warn_count
    title="DQ warnings"
    fmt=num0
    link="/data-quality"
/>

<BigValue
    data={dq_kpi}
    value=error_count
    title="DQ errors"
    fmt=num0
    link="/data-quality"
/>

{#if mtd.length}
<p style="color:#64748b;font-size:13px;margin:4px 0 0;">
{mtd[0].month_label} MTD · bookings <Value data={mtd} column=bookings_usd fmt=usd1m /> · billings <Value data={mtd} column=billings_usd fmt=usd1m />
</p>
{/if}
