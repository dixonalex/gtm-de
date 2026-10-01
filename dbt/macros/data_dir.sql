{# flags.PROJECT_DIR is not exposed to Jinja. LOG_PATH is absolute and sits in the dbt project. #}
{% macro data_dir() %}
{{- var('data_dir', env_var('GTM_DATA_DIR', flags.LOG_PATH.rsplit('/logs', 1)[0] ~ '/../data')) -}}
{% endmacro %}
