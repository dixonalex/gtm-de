{{ config(materialized='table') }}

with accounts as (
    select
        account_id,
        name,
        website,
        billing_country,
        parent_id,
        currency_iso_code,
        {{ account_domain_key('website') }} as domain_key,
        {{ account_match_name('name') }} as norm_name
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
        a.norm_name as norm_a,
        b.norm_name as norm_b,
        case
            when a.norm_name is null or b.norm_name is null then null
            else damerau_levenshtein(a.norm_name, b.norm_name)
        end as name_edit_distance,
        case
            when a.norm_name is null or b.norm_name is null then null
            else length(a.norm_name) - length(replace(a.norm_name, ' ', '')) + 1
        end as tokens_a,
        case
            when a.norm_name is null or b.norm_name is null then null
            else length(b.norm_name) - length(replace(b.norm_name, ' ', '')) + 1
        end as tokens_b,
        case
            when a.domain_key is not null and a.domain_key = b.domain_key then 1
            else 0
        end as domain_equal,
        case
            when a.billing_country is not null
             and b.billing_country is not null
             and a.billing_country = b.billing_country
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
    inner join hierarchy ha on a.account_id = ha.account_id
    inner join hierarchy hb on b.account_id = hb.account_id
    inner join v2 va on a.account_id = va.account_id
    inner join v2 vb on b.account_id = vb.account_id
),

features as (
    select
        account_id_a,
        account_id_b,
        name_a,
        name_b,
        website_a,
        website_b,
        billing_country_a,
        billing_country_b,
        name_edit_distance,
        name_edit_distance / nullif(greatest(length(norm_a), length(norm_b)), 0) as name_edit_ratio,
        case
            when tokens_a is not null and tokens_a = tokens_b then 1
            else 0
        end as token_count_equal,
        domain_equal,
        country_equal,
        parent_linked,
        auto_merged
    from pairs
),

-- parent_linked pairs are dropped before this CTE. The remaining weights only order
-- pairs that already share an edit ratio: domain and country cannot outweigh one character.
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
        name_edit_distance,
        name_edit_ratio,
        token_count_equal,
        domain_equal,
        country_equal,
        parent_linked,
        auto_merged,
        1.0 as w_name_edit_ratio,   -- score starts here; lower means a smaller fraction of the longer name must change
        0.0001 as w_domain_equal,   -- tie break only; far below one character so it cannot cross an edit-distance bucket
        0.0001 as w_country_equal   -- tie break only; same scale as the domain tie break
    from features
    where parent_linked = 0
      and name_edit_distance is not null
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
    name_edit_distance,
    name_edit_ratio,
    token_count_equal,
    domain_equal,
    country_equal,
    parent_linked,
    auto_merged,
    name_edit_ratio * w_name_edit_ratio
        - domain_equal * w_domain_equal
        - country_equal * w_country_equal as match_score,
    -- Distance 2 is empty. Distance 0-1 holds the remaining true pairs; distance 3+ is a separate mass.
    case
        when auto_merged then 'auto_merge'
        when name_edit_distance <= 1 then 'review'
        else 'no_match'
    end as tier
from scored
