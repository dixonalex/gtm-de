{# Weekdays strictly after start_date through end_date. No holiday calendar. #}
{% macro business_days(start_date, end_date) %}
case
    when {{ end_date }} is null or {{ start_date }} is null or {{ end_date }} <= {{ start_date }} then 0
    else (
        select count(*)::integer
        from generate_series(
            cast({{ start_date }} as date) + interval 1 day,
            cast({{ end_date }} as date),
            interval 1 day
        ) as t(d)
        where extract('dow' from t.d) between 1 and 5
    )
end
{% endmacro %}
