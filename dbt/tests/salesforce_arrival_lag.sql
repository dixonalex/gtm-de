{{ config(severity='warn', store_failures=true) }}

-- Salesforce rows loaded more than 72 hours after SystemModstamp, inside the last 7 days.
{% set grains = [
    ('stg_salesforce__account', 'account_id'),
    ('stg_salesforce__user', 'user_id'),
    ('stg_salesforce__dated_conversion_rate', 'dated_conversion_rate_id'),
    ('stg_salesforce__product2', 'product_id'),
    ('stg_salesforce__pricebook2', 'pricebook_id'),
    ('stg_salesforce__pricebook_entry', 'pricebook_entry_id'),
    ('stg_salesforce__opportunity', 'opportunity_id'),
    ('stg_salesforce__opportunity_history', 'opportunity_history_id'),
    ('stg_salesforce__opportunity_line_item', 'opportunity_line_item_id'),
    ('stg_salesforce__quote', 'quote_id'),
    ('stg_salesforce__quote_line_item', 'quote_line_item_id'),
    ('stg_salesforce__order', 'order_id'),
    ('stg_salesforce__order_item', 'order_item_id'),
] %}

{% for model_name, key in grains %}
select
    '{{ model_name }}' as object_name,
    {{ key }} as record_id,
    _loaded_at,
    system_modstamp
from {{ ref(model_name) }}
where _loaded_at > system_modstamp + interval '72 hours'
  and date_diff('day', cast(_loaded_at as date), {{ as_of_date() }}) between 0 and 7
{% if not loop.last %}
union all
{% endif %}
{% endfor %}
