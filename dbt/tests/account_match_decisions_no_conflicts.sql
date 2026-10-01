-- Conflicting decisions for the same unordered pair.
select
    least(account_id_a, account_id_b) as account_id_a,
    greatest(account_id_a, account_id_b) as account_id_b,
    count(distinct decision) as decisions
from {{ ref('account_match_decisions') }}
group by 1, 2
having count(distinct decision) > 1
