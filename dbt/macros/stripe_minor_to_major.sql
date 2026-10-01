{% macro stripe_minor_to_major(amount_column, currency_column) %}
    {#- Stripe zero-decimal currencies: amount is already in major units. https://docs.stripe.com/currencies#zero-decimal -#}
    case
        when upper(cast({{ currency_column }} as varchar)) in (
            'BIF', 'CLP', 'DJF', 'GNF', 'JPY', 'KMF', 'KRW', 'MGA',
            'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
        )
            then cast({{ amount_column }} as decimal(18, 4))
        else cast({{ amount_column }} as decimal(18, 4)) / 100
    end
{% endmacro %}
