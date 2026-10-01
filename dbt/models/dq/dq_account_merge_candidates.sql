with accounts as (
    select
        account_id,
        name,
        website,
        billing_country,
        parent_id,
        currency_iso_code,
        {{ account_name_key('name') }} as name_key,
        master_account_id
    from {{ ref('stg_salesforce__account') }}
    inner join {{ ref('int_accounts__deduped') }} using (account_id)
),

pairs as (
    select
        a.account_id as account_id_a,
        b.account_id as account_id_b,
        a.name as name_a,
        b.name as name_b,
        a.website as website_a,
        b.website as website_b,
        a.billing_country as billing_country_a,
        b.billing_country as billing_country_b,
        jaro_winkler_similarity(a.name_key, b.name_key) as similarity,
        'similar_normalized_name' as reason
    from accounts a
    inner join accounts b
        on a.account_id < b.account_id
       and a.currency_iso_code = b.currency_iso_code
       and a.master_account_id != b.master_account_id
       and a.name_key is not null
       and b.name_key is not null
    where jaro_winkler_similarity(a.name_key, b.name_key) >= 0.90
      and not coalesce(a.parent_id = b.account_id, false)
      and not coalesce(b.parent_id = a.account_id, false)
)

select * from pairs
