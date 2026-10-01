---
title: Pipeline and forecast
hide_title: true
---

```sql teams
select 'All' as value
union all
select distinct team as value from gtm.sales_attainment where team != 'All'
order by value
```

```sql reps
select 'All' as value
union all
select distinct rep as value from gtm.sales_attainment where rep != 'All'
order by value
```

```sql kpi
select *
from gtm.sales_attainment
where segment = '${inputs.segment.value}'
  and team = '${inputs.team.value}'
  and rep = '${inputs.rep.value}'
```

```sql segments
select *
from gtm.sales_attainment
where team = '${inputs.team.value}'
  and rep = '${inputs.rep.value}'
  and segment != 'All'
  and ('${inputs.segment.value}' = 'All' or segment = '${inputs.segment.value}')
order by case segment
  when 'Enterprise' then 1
  when 'Mid-market' then 2
  when 'SMB' then 3
  when 'Startups' then 4
  else 5
end
```

```sql forecast
select *
from gtm.sales_forecast
where segment = '${inputs.segment.value}'
  and team = '${inputs.team.value}'
  and rep = '${inputs.rep.value}'
order by week_index
```

```sql months
select *
from gtm.sales_bookings
where segment = '${inputs.segment.value}'
  and team = '${inputs.team.value}'
  and rep = '${inputs.rep.value}'
order by month_key
```

```sql slips
select *
from gtm.slipped_deals
where ('${inputs.segment.value}' = 'All' or segment = '${inputs.segment.value}')
  and ('${inputs.rep.value}' = 'All' or owner_name = '${inputs.rep.value}')
order by amount_usd desc
```

```sql freshness
select * from gtm.connector_freshness order by connector_id
```

<UrlSync keys="segment,team,rep" defaults="segment:All,team:All,rep:All" />

<SalesView {kpi} {segments} {forecast} {months} {slips} {freshness}>
  <div slot="controls">
    <Dropdown name="quarter" title="Period" defaultValue="2026-Q3">
      <DropdownOption value="2026-Q3" valueLabel="Q3 FY26" />
    </Dropdown>
    <Dropdown name="segment" title="Segment" defaultValue="All">
      <DropdownOption value="All" valueLabel="All" />
      <DropdownOption value="Enterprise" valueLabel="Enterprise" />
      <DropdownOption value="Mid-market" valueLabel="Mid-market" />
      <DropdownOption value="SMB" valueLabel="SMB" />
      <DropdownOption value="Startups" valueLabel="Startups" />
      <DropdownOption value="Public sector" valueLabel="Public sector" />
    </Dropdown>
    <Dropdown name="team" title="Team" data={teams} defaultValue="All" />
    <Dropdown name="rep" title="Rep" data={reps} defaultValue="All" />
  </div>
</SalesView>
