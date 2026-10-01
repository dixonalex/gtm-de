{{ config(severity='error', store_failures=true) }}

-- A rejected pair must not share a billing master through some other edge.
select
    d.account_id_a,
    d.account_id_b,
    a.master_account_id
from {{ ref('account_match_decisions') }} d
inner join {{ ref('int_accounts__deduped') }} a
    on a.account_id = d.account_id_a
inner join {{ ref('int_accounts__deduped') }} b
    on b.account_id = d.account_id_b
where d.decision = 'reject'
  and a.master_account_id = b.master_account_id
