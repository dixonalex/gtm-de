select
    queue_rank,
    account_id_a,
    account_id_b,
    name_a,
    name_b,
    website_a,
    website_b,
    billing_country_a,
    billing_country_b,
    arr_at_stake_usd,
    case
        when billing_country_a = billing_country_b and name_edit_distance = 0
            then 'Same normalized name'
        when billing_country_a = billing_country_b and name_edit_distance = 1
            then 'Same country · names 1 edit apart'
        when billing_country_a = billing_country_b then 'Same country'
        else null
    end as signal_for,
    case
        when website_a is distinct from website_b then 'Different domain'
        else null
    end as signal_against
from dq.dq_account_review_queue
