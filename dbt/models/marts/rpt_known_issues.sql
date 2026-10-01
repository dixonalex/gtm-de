-- The four known issue types. Sizes are measured; nothing here is a raw record.
with invoices as (
    select
        count(*) filter (where metadata_salesforce_order_id is null)::double
            / nullif(count(*), 0) as share
    from {{ ref('stg_billing__invoice') }}
    where status != 'void'
),

pairs as (
    select count(*) as pending_pairs
    from {{ ref('dq_account_review_queue') }}
),

late as (
    select
        count(*) filter (where date_diff('day', system_modstamp, _loaded_at) >= 3)::double
            / nullif(count(*), 0) as share
    from {{ ref('stg_salesforce__opportunity') }}
),

wins as (
    select
        count(*) filter (where won_without_order)::double / nullif(count(*), 0) as share
    from {{ ref('stg_salesforce__opportunity') }}
    where is_won
      and close_date > {{ as_of_date() }} - interval 90 day
      and close_date <= {{ as_of_date() }}
)

select
    k.issue_key,
    k.issue_type,
    k.handling_rule,
    k.age_days,
    k.sort_order,
    case k.issue_key
        when 'invoices_missing_order' then (select share from invoices)
        when 'duplicate_pairs' then (select pending_pairs from pairs)
        when 'late_salesforce' then (select share from late)
        when 'won_without_order' then (select share from wins)
    end as size_value,
    case k.issue_key
        when 'duplicate_pairs' then 'count'
        else 'share'
    end as size_unit
from {{ ref('known_issues') }} k
