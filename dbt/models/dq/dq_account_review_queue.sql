with review as (
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
        match_score
    from {{ ref('int_accounts__match_candidates') }}
    where tier = 'review'
),

decisions as (
    select
        least(account_id_a, account_id_b) as account_id_a,
        greatest(account_id_a, account_id_b) as account_id_b
    from {{ ref('account_match_decisions') }}
),

pending as (
    select r.*
    from review r
    where not exists (
        select 1
        from decisions d
        where d.account_id_a = r.account_id_a
          and d.account_id_b = r.account_id_b
    )
),

masters as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped_v2') }}
),

arr as (
    select
        master_account_id,
        committed_arr_usd
    from {{ ref('fct_arr_monthly') }}
    where month_end = (
        select max(month_end)
        from {{ ref('fct_arr_monthly') }}
        where month_end <= {{ as_of_date() }}
    )
),

valued as (
    select
        p.account_id_a,
        p.account_id_b,
        p.name_a,
        p.name_b,
        p.website_a,
        p.website_b,
        p.billing_country_a,
        p.billing_country_b,
        p.name_edit_distance,
        p.match_score,
        coalesce(arra.committed_arr_usd, 0) + coalesce(arrb.committed_arr_usd, 0) as arr_at_stake_usd
    from pending p
    inner join masters ma on p.account_id_a = ma.account_id
    inner join masters mb on p.account_id_b = mb.account_id
    left join arr arra on ma.master_account_id = arra.master_account_id
    left join arr arrb on mb.master_account_id = arrb.master_account_id
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
    match_score,
    arr_at_stake_usd,
    row_number() over (
        order by arr_at_stake_usd desc, match_score asc, account_id_a, account_id_b
    ) as queue_rank
from valued
