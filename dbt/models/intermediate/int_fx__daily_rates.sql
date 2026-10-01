with rates as (
    select
        iso_code as currency_code,
        conversion_rate,
        start_date,
        next_start_date
    from {{ ref('stg_salesforce__dated_conversion_rate') }}
),

bounds as (
    select
        min(start_date) as start_date,
        max(next_start_date) as end_exclusive
    from rates
),

spine as (
    select cast(unnest(generate_series(start_date, end_exclusive - interval 1 day, interval 1 day)) as date) as rate_date
    from bounds
)

select
    spine.rate_date,
    rates.currency_code,
    rates.conversion_rate
from spine
inner join rates
    on spine.rate_date >= rates.start_date
   and spine.rate_date < rates.next_start_date
