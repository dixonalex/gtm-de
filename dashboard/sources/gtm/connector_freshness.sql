select
    strftime(as_of_date, '%Y-%m-%d') as as_of_date,
    connector_id,
    case connector_id
        when 'salesforce' then 'Salesforce'
        when 'stripe' then 'Stripe'
    end as connector,
    strftime(last_successful_sync, '%Y-%m-%d %H:%M') || ' UTC' as last_successful_sync,
    age_hours,
    age_minutes,
    status
from dq.dq_connector_freshness
