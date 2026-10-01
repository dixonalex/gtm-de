-- New and expansion ACV by month and segment. Dollars, not display strings.
with lines as (
    select
        cast(date_trunc('month', b.booking_date) + interval 1 month - interval 1 day as date) as month_end,
        a.segment,
        b.booking_type,
        b.bookings_acv_usd
    from {{ ref('fct_bookings') }} b
    left join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    where b.booking_type in ('new', 'expansion')
)

select
    month_end,
    segment,
    sum(bookings_acv_usd) as bookings_acv_usd,
    sum(case when booking_type = 'new' then bookings_acv_usd else 0 end) as new_acv_usd,
    sum(case when booking_type = 'expansion' then bookings_acv_usd else 0 end) as expansion_acv_usd
from lines
group by month_end, segment
