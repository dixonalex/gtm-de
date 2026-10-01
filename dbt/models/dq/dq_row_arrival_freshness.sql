-- Newest row per object, aged the same way as connector freshness (naive UTC vs UTC now).
{% set objects = [
    ('stg_salesforce__opportunity', 'opportunity'),
    ('stg_salesforce__opportunity_history', 'opportunity_history'),
    ('stg_billing__invoice', 'invoice'),
    ('stg_billing__charge', 'charge'),
] %}

with newest as (
    {% for model_name, object_name in objects %}
    select
        '{{ object_name }}' as object_name,
        max(_loaded_at) as max_loaded_at
    from {{ ref(model_name) }}
    {% if not loop.last %}
    union all
    {% endif %}
    {% endfor %}
),

aged as (
    select
        object_name,
        max_loaded_at,
        date_diff('hour', max_loaded_at, timezone('UTC', current_timestamp)) as age_hours,
        48 as sla_warn_hours,
        24 * 7 as sla_error_hours
    from newest
)

select
    object_name,
    max_loaded_at,
    age_hours,
    '48h warn / 7d error' as sla,
    case
        when age_hours >= sla_error_hours then 'ERROR'
        when age_hours >= sla_warn_hours then 'WARN'
        else 'PASS'
    end as status
from aged
