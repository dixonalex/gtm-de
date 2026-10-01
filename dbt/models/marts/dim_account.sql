with accounts as (
    select
        account_id,
        name,
        website
    from {{ ref('stg_salesforce__account') }}
),

deduped as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

hierarchy as (
    select account_id, ultimate_parent_account_id
    from {{ ref('int_accounts__hierarchy') }}
)

select
    a.account_id,
    a.name,
    a.website,
    d.master_account_id,
    h.ultimate_parent_account_id
from accounts a
inner join deduped d on a.account_id = d.account_id
inner join hierarchy h on a.account_id = h.account_id
