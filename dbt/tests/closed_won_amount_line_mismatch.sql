{{ config(severity='warn', store_failures=true) }}

-- Closed Won amount differs from the sum of opportunity lines.
select
    o.opportunity_id,
    o.amount as opportunity_amount,
    coalesce(l.line_amount, 0) as line_amount
from {{ ref('stg_salesforce__opportunity') }} o
left join (
    select
        opportunity_id,
        sum(total_price) as line_amount
    from {{ ref('stg_salesforce__opportunity_line_item') }}
    group by opportunity_id
) l on o.opportunity_id = l.opportunity_id
where o.is_won
  and abs(o.amount - coalesce(l.line_amount, 0)) > 0.01
