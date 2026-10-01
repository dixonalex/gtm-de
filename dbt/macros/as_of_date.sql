{# Warehouse as-of date. Defaults to the latest successful Salesforce sync. Override with --vars '{as_of_date: YYYY-MM-DD}'. #}
{% macro as_of_date() -%}
{%- if var('as_of_date', none) is not none -%}
cast('{{ var("as_of_date") }}' as date)
{%- else -%}
(select cast(max(sync_end) as date) from {{ ref('stg_fivetran_log__connector_sync') }} where connector_id = 'salesforce' and status = 'SUCCESSFUL')
{%- endif -%}
{%- endmacro %}
