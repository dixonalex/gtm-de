{{ config(severity='warn') }}

-- Stripe is outside its 24-hour freshness SLA against the extract clock.
select
    connector_id,
    age_hours
from {{ ref('dq_connector_freshness') }}
where connector_id = 'stripe'
  and age_hours >= (
      select cast(threshold_value as integer)
      from {{ ref('policy_thresholds') }}
      where threshold_key = 'freshness_stripe_hours'
  )
