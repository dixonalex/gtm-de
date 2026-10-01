---
title: Revenue review
hide_title: true
---

```sql periods
select distinct month_key as value, strftime(month_end, '%b %Y') as label
from gtm.executive_month
where segment = 'All' and region = 'All'
order by value desc
```

```sql regions
select 'All' as value
union all
select distinct region as value
from gtm.executive_month
where region != 'All'
order by value
```

```sql kpi
select *
from gtm.executive_month
where month_key = '${inputs.period.value}'
  and segment = '${inputs.segment.value}'
  and region = '${inputs.region.value}'
```

```sql trend
select *
from gtm.executive_month
where segment = '${inputs.segment.value}'
  and region = '${inputs.region.value}'
  and month_key >= '2026-01-01'
  and month_key <= '${inputs.period.value}'
order by month_key
```

```sql notes
select *
from gtm.executive_commentary
where month_key = '${inputs.period.value}'
  and view_segment = '${inputs.segment.value}'
  and view_region = '${inputs.region.value}'
order by sort_order, label
```

```sql movers
select *
from gtm.executive_mover
where month_key = '${inputs.period.value}'
  and segment = '${inputs.segment.value}'
  and region = '${inputs.region.value}'
order by side, rank
```

```sql freshness
select * from gtm.connector_freshness order by connector_id
```

```sql events
select * from gtm.chart_events
```

<UrlSync keys="period,segment,region" defaults="period:2026-08-31,segment:All,region:All" primary="period" />

<ExecutiveView {kpi} {trend} {notes} {movers} {freshness} {events}>
  <div slot="controls">
    <Dropdown name="period" data={periods} label="label" defaultValue="2026-08-31" />
    <Dropdown name="segment" title="Segment" defaultValue="All">
      <DropdownOption value="All" valueLabel="All" />
      <DropdownOption value="Enterprise" valueLabel="Enterprise" />
      <DropdownOption value="Mid-market" valueLabel="Mid-market" />
      <DropdownOption value="SMB" valueLabel="SMB" />
      <DropdownOption value="Startups" valueLabel="Startups" />
      <DropdownOption value="Public sector" valueLabel="Public sector" />
    </Dropdown>
    <Dropdown name="region" title="Region" data={regions} defaultValue="All" />
  </div>
</ExecutiveView>
