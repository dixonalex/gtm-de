---
title: Sales
---

```sql bookings
select * from gtm.bookings_month
```

```sql forecast
select * from gtm.forecast_call
```

```sql quota
select * from gtm.quota
```

```sql slips
select * from gtm.slipped_deals
```

```sql freshness
select * from gtm.connector_freshness
```

<SalesView {bookings} {forecast} {quota} slips={slips} {freshness} />
