---
title: Finance
---

```sql bookings
select * from gtm.bookings_month
```

```sql bridge
select * from gtm.billings_bridge
```

```sql currency
select * from gtm.billings_currency
```

```sql aging
select * from gtm.ar_aging
```

```sql unbilled
select * from gtm.booked_not_billed
```

```sql burn
select * from gtm.commit_burn
```

```sql freshness
select * from gtm.connector_freshness
```

<FinanceView {bookings} bridge={bridge} {currency} {aging} {unbilled} {burn} {freshness} />
