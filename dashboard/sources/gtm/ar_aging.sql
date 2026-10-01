select
    month_end,
    current_usd,
    bucket_1_30_usd,
    bucket_31_90_usd,
    over_90_usd,
    ar_usd,
    dso_days
from marts.fct_ar_aging
where month_end >= date '2026-03-01'
order by month_end
