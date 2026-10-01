-- Open opportunities whose close date moved out of the current quarter during the latest week.
with history as (
    select
        opportunity_id,
        close_date,
        cast(created_date as date) as changed_on,
        lag(close_date) over (
            partition by opportunity_id
            order by created_date, opportunity_history_id
        ) as previous_close_date
    from {{ ref('stg_salesforce__opportunity_history') }}
),

changes as (
    select *
    from history
    where previous_close_date is not null
      and close_date is distinct from previous_close_date
),

quarter as (
    select
        cast(date_trunc('quarter', {{ as_of_date() }}) as date) as quarter_start,
        cast(date_trunc('quarter', {{ as_of_date() }}) + interval 3 month - interval 1 day as date) as quarter_end,
        cast(date_trunc('week', {{ as_of_date() }}) as date) as week_start
),

slipped as (
    select
        c.opportunity_id,
        count(*) as slip_count,
        max(case
            when c.changed_on >= q.week_start
             and c.changed_on <= {{ as_of_date() }}
             and c.previous_close_date between q.quarter_start and q.quarter_end
             and c.close_date > q.quarter_end
            then 1 else 0
        end) as slipped_this_week,
        arg_max(
            c.previous_close_date,
            case
                when c.changed_on >= q.week_start
                 and c.changed_on <= {{ as_of_date() }}
                 and c.previous_close_date between q.quarter_start and q.quarter_end
                 and c.close_date > q.quarter_end
                then c.changed_on
            end
        ) as previous_close_date
    from changes c
    cross join quarter q
    group by c.opportunity_id
)

select
    o.opportunity_id,
    a.name as account_name,
    a.segment,
    u.name as owner_name,
    o.amount as amount_local,
    o.amount / coalesce(fx.conversion_rate, 1) as amount_usd,
    o.close_date,
    s.previous_close_date,
    s.slip_count
from slipped s
inner join {{ ref('stg_salesforce__opportunity') }} o
    on s.opportunity_id = o.opportunity_id
inner join {{ ref('stg_salesforce__account') }} a
    on o.account_id = a.account_id
left join {{ ref('stg_salesforce__user') }} u
    on o.owner_id = u.user_id
left join {{ ref('int_fx__daily_rates') }} fx
    on fx.rate_date = least(o.close_date, {{ as_of_date() }})
   and fx.currency_code = o.currency_iso_code
cross join quarter q
where not o.is_closed
  and s.slipped_this_week = 1
  and o.close_date > q.quarter_end
