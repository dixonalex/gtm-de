---
title: Pipeline
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

```sql pipeline_headline
select
    strftime(month_end, '%b %Y') as month_label,
    sum(amount_usd) as open_pipeline_usd
from gtm.pipeline
where month_end = (select max(month_end) from gtm.pipeline)
group by month_end
```

```sql pipeline_by_forecast
select
    month_end,
    coalesce(forecast_category, 'Uncategorized') as forecast_category,
    sum(amount_usd) as pipeline_usd
from gtm.pipeline
group by month_end, forecast_category
order by month_end
```

## Open pipeline · <Value data={pipeline_headline} column=month_label /> is <Value data={pipeline_headline} column=open_pipeline_usd fmt=usd1m />

<BarChart
    data={pipeline_by_forecast}
    x=month_end
    y=pipeline_usd
    series=forecast_category
    seriesOrder={['Pipeline', 'Best Case', 'Commit']}
    type=stacked
    yFmt=usd1m
    xFmt=shortdate
/>

```sql pipeline_by_stage
select
    stage_name,
    sum(amount_usd) as pipeline_usd
from gtm.pipeline
where month_end = (select max(month_end) from gtm.pipeline)
group by stage_name
order by case stage_name
    when 'Prospecting' then 1
    when 'Qualification' then 2
    when 'Needs Analysis' then 3
    when 'Proposal/Price Quote' then 4
    when 'Negotiation/Review' then 5
    else 6
end
```

```sql stage_leader
select stage_name, sum(amount_usd) as pipeline_usd
from gtm.pipeline
where month_end = (select max(month_end) from gtm.pipeline)
group by stage_name
order by pipeline_usd desc
limit 1
```

## <Value data={stage_leader} column=stage_name /> holds the most open pipeline, <Value data={stage_leader} column=pipeline_usd fmt=usd1m />

<BarChart
    data={pipeline_by_stage}
    x=stage_name
    y=pipeline_usd
    swapXY=true
    yFmt=usd1m
    labels=true
    labelFmt=usd1m
    legend=false
    sort=false
/>

```sql slips
select
    opportunity_name,
    account_name,
    previous_close_date,
    close_date,
    changed_on,
    days_slipped,
    amount_usd
from gtm.close_slips
order by amount_usd desc
```

```sql slip_count
select count(*) as deals, sum(amount_usd) as amount_usd
from gtm.close_slips
```

## <Value data={slip_count} column=deals fmt=num0 /> deals slipped CloseDate this quarter, <Value data={slip_count} column=amount_usd fmt=usd1m /> of pipeline

<DataTable data={slips} rows=20 search=true emptyMessage="No CloseDate slips in the latest quarter.">
    <Column id=opportunity_name title="Opportunity" wrap=true/>
    <Column id=account_name title="Account" wrap=true/>
    <Column id=previous_close_date title="Previous close"/>
    <Column id=close_date title="New close"/>
    <Column id=changed_on title="Changed"/>
    <Column id=days_slipped title="Days slipped" fmt=num0/>
    <Column id=amount_usd title="Amount" fmt=usd1m/>
</DataTable>
