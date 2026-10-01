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
    name_edit_distance,
    match_score,
    arr_at_stake_usd
from dq.dq_account_review_queue
