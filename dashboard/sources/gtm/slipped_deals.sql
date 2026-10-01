with hist as (
    select
        opportunity_id,
        close_date,
        lag(close_date) over (
            partition by opportunity_id
            order by created_date, opportunity_history_id
        ) as previous_close_date,
        cast(created_date as date) as changed_on
    from staging.stg_salesforce__opportunity_history
)
select
    s.opportunity_id,
    s.account_name,
    s.segment,
    s.owner_name,
    s.amount_usd,
    s.close_date,
    s.slip_count,
    h.previous_close_date
from marts.fct_slipped_deals s
left join hist h
    on h.opportunity_id = s.opportunity_id
   and h.close_date = s.close_date
qualify row_number() over (partition by s.opportunity_id order by h.changed_on desc nulls last) = 1
