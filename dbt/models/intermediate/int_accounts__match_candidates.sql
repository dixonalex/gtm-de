with accounts as (
    select
        account_id,
        name,
        website,
        billing_country,
        parent_id,
        currency_iso_code,
        created_date,
        {{ account_domain_key('website') }} as domain_key,
        {{ account_name_key('name') }} as name_key
    from {{ ref('stg_salesforce__account') }}
),

hierarchy as (
    select account_id, ultimate_parent_account_id
    from {{ ref('int_accounts__hierarchy') }}
),

v2 as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped_v2') }}
),

blocked as (
    select
        a.account_id as account_id_a,
        b.account_id as account_id_b,
        a.name as name_a,
        b.name as name_b,
        a.website as website_a,
        b.website as website_b,
        a.billing_country as billing_country_a,
        b.billing_country as billing_country_b,
        a.name_key as name_key_a,
        b.name_key as name_key_b,
        a.domain_key as domain_key_a,
        b.domain_key as domain_key_b,
        case
            when a.name_key is null or b.name_key is null then 0
            else jaro_winkler_similarity(a.name_key, b.name_key)
        end as name_jw,
        -- Same registered domain. Null websites are not a match.
        case
            when a.domain_key is not null and a.domain_key = b.domain_key then 1
            else 0
        end as domain_equal,
        -- Null country compares equal, matching the v2 auto-merge rule.
        case
            when a.billing_country is null
              or b.billing_country is null
              or a.billing_country = b.billing_country
                then 1
            else 0
        end as country_equal,
        case
            when coalesce(a.parent_id = b.account_id, false)
              or coalesce(b.parent_id = a.account_id, false)
              or ha.ultimate_parent_account_id = hb.ultimate_parent_account_id
                then 1
            else 0
        end as parent_linked,
        va.master_account_id = vb.master_account_id as auto_merged
    from accounts a
    inner join accounts b
        on a.account_id < b.account_id
       and a.currency_iso_code = b.currency_iso_code
       and (
            (a.domain_key is not null and a.domain_key = b.domain_key)
            or (
                a.name_key is not null
                and b.name_key is not null
                and left(a.name_key, 4) = left(b.name_key, 4)
            )
       )
    inner join hierarchy ha on a.account_id = ha.account_id
    inner join hierarchy hb on b.account_id = hb.account_id
    inner join v2 va on a.account_id = va.account_id
    inner join v2 vb on b.account_id = vb.account_id
),

-- Weights are fixed before looking at a threshold. parent_linked dominates:
-- name 1 + domain 0.20 + country 0.20 - 1.50 = -0.10, so a hierarchy pair cannot clear a positive cutoff.
scored as (
    select
        account_id_a,
        account_id_b,
        name_a,
        name_b,
        website_a,
        website_b,
        billing_country_a,
        billing_country_b,
        name_jw,
        domain_equal,
        country_equal,
        parent_linked,
        auto_merged,
        1.00 as w_name_jw,       -- primary identity signal; jaro-winkler is already on [0, 1]
        0.20 as w_domain_equal,  -- shared website is supporting evidence; safe domain merges are already auto
        0.20 as w_country_equal, -- compatible billing country; a mismatch is the collision pattern
        -1.50 as w_parent_linked -- hierarchy, not a duplicate; strong enough to keep those pairs below zero
    from blocked
)

select
    account_id_a,
    account_id_b,
    name_a,
    name_b,
    website_a,
    website_b,
    billing_country_a,
    billing_country_b,
    name_jw,
    domain_equal,
    country_equal,
    parent_linked,
    auto_merged,
    name_jw * w_name_jw
        + domain_equal * w_domain_equal
        + country_equal * w_country_equal
        + parent_linked * w_parent_linked as match_score
from scored
