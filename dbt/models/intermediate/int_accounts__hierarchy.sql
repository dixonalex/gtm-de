with recursive accounts as (
    select
        account_id,
        parent_id
    from {{ ref('stg_salesforce__account') }}
),

walk as (
    select
        account_id,
        account_id as ultimate_parent_account_id,
        0 as depth
    from accounts
    where parent_id is null

    union all

    select
        child.account_id,
        walk.ultimate_parent_account_id,
        walk.depth + 1
    from accounts child
    inner join walk on child.parent_id = walk.account_id
    where walk.depth < 10
)

select
    account_id,
    ultimate_parent_account_id
from walk
