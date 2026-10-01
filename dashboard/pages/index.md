---
title: Executive
---

```sql plan
select * from gtm.arr_plan
```

```sql bridge
select * from gtm.arr_bridge
```

```sql movement
select * from gtm.arr_movement
```

```sql nrr
select * from gtm.nrr_grr
```

```sql commentary
select * from gtm.commentary
```

```sql bookings
select * from gtm.bookings_month
```

```sql freshness
select * from gtm.connector_freshness
```

```sql events
select * from gtm.chart_events
```

<ExecutiveView
  plan={plan}
  bridge={bridge}
  movement={movement}
  nrr={nrr}
  commentary={commentary}
  bookings={bookings}
  freshness={freshness}
  events={events}
/>
