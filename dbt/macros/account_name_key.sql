{% macro account_name_key(name_column) %}
nullif(
    regexp_replace(
        trim(
            regexp_replace(
                replace(
                    regexp_replace(lower({{ name_column }}), '\s*\([^)]*\)', '', 'g'),
                    '.',
                    ''
                ),
                '[^a-z0-9]+',
                ' ',
                'g'
            )
        ),
        '(\s+(incorporated|holdings|group|corp|gmbh|llc|ltd|inc|kk|co))+$',
        ''
    ),
    ''
)
{% endmacro %}

{% macro account_domain_key(website_column) %}
nullif(
    split_part(
        regexp_replace(
            regexp_replace(lower({{ website_column }}), '^https?://', ''),
            '^www\.',
            ''
        ),
        '/',
        1
    ),
    ''
)
{% endmacro %}
