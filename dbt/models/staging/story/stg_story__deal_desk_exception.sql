select
    cast(account_name as varchar) as account_name,
    cast(record_id as varchar) as record_id,
    cast(exception_type as varchar) as exception_type,
    cast(opened_on as date) as opened_on,
    cast(nullif(nullif(resolved_on, ''), 'open') as date) as resolved_on,
    cast(amount_usd as double) as amount_usd,
    cast(owner_name as varchar) as owner_name,
    cast(sla_bd as integer) as sla_bd,
    cast(age_days as double) as age_days
from {{ source('story', 'deal_desk_exception') }}
