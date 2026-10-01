-- Hours between Salesforce SystemModstamp and the row's _loaded_at, by object and arrival week.
{% set grains = [
    ('stg_salesforce__account', 'account', 'account_id'),
    ('stg_salesforce__user', 'user', 'user_id'),
    ('stg_salesforce__dated_conversion_rate', 'dated_conversion_rate', 'dated_conversion_rate_id'),
    ('stg_salesforce__product2', 'product2', 'product_id'),
    ('stg_salesforce__pricebook2', 'pricebook2', 'pricebook_id'),
    ('stg_salesforce__pricebook_entry', 'pricebook_entry', 'pricebook_entry_id'),
    ('stg_salesforce__opportunity', 'opportunity', 'opportunity_id'),
    ('stg_salesforce__opportunity_history', 'opportunity_history', 'opportunity_history_id'),
    ('stg_salesforce__opportunity_line_item', 'opportunity_line_item', 'opportunity_line_item_id'),
    ('stg_salesforce__quote', 'quote', 'quote_id'),
    ('stg_salesforce__quote_line_item', 'quote_line_item', 'quote_line_item_id'),
    ('stg_salesforce__order', 'order', 'order_id'),
    ('stg_salesforce__order_item', 'order_item', 'order_item_id'),
] %}

with arrivals as (
    {% for model_name, object_name, key in grains %}
    select
        '{{ object_name }}' as object_name,
        cast(date_trunc('week', _loaded_at) as date) as week_start,
        date_diff('hour', system_modstamp, _loaded_at) as lag_hours
    from {{ ref(model_name) }}
    {% if not loop.last %}
    union all
    {% endif %}
    {% endfor %}
)

select
    object_name,
    week_start,
    count(*) as row_count,
    quantile_cont(lag_hours, 0.5) as p50_lag_hours,
    quantile_cont(lag_hours, 0.95) as p95_lag_hours
from arrivals
group by object_name, week_start
