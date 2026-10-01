-- dedup-rule-v3. Components of v2 auto-merge edges plus approved decisions, minus rejected edges.
with recursive accounts as (
    select
        account_id,
        created_date
    from {{ ref('stg_salesforce__account') }}
),

v2 as (
    select account_id, master_account_id, match_rule
    from {{ ref('int_accounts__deduped_v2') }}
),

decisions as (
    select
        least(account_id_a, account_id_b) as account_id_a,
        greatest(account_id_a, account_id_b) as account_id_b,
        decision
    from {{ ref('account_match_decisions') }}
),

raw_edges as (
    select
        least(account_id, master_account_id) as account_id_a,
        greatest(account_id, master_account_id) as account_id_b
    from v2
    where account_id != master_account_id

    union

    select account_id_a, account_id_b
    from decisions
    where decision = 'approve'
),

edges as (
    select r.account_id_a, r.account_id_b
    from raw_edges r
    where not exists (
        select 1
        from decisions d
        where d.decision = 'reject'
          and d.account_id_a = r.account_id_a
          and d.account_id_b = r.account_id_b
    )
),

undirected as (
    select account_id_a as src, account_id_b as dst from edges
    union all
    select account_id_b, account_id_a from edges
),

walk as (
    select
        account_id as start_id,
        account_id as reached,
        cast(account_id as varchar) as path,
        0 as depth
    from accounts

    union all

    select
        w.start_id,
        u.dst,
        w.path || ',' || u.dst,
        w.depth + 1
    from walk w
    inner join undirected u on u.src = w.reached
    where w.depth < 12
      and not contains(',' || w.path || ',', ',' || u.dst || ',')
),

component as (
    select
        start_id as account_id,
        min(reached) as component_id
    from walk
    group by start_id
),

ranked as (
    select
        c.component_id,
        a.account_id,
        row_number() over (
            partition by c.component_id
            order by a.created_date, a.account_id
        ) as rn
    from component c
    inner join accounts a on c.account_id = a.account_id
),

survivor as (
    select component_id, account_id as master_account_id
    from ranked
    where rn = 1
)

select
    c.account_id,
    s.master_account_id,
    case
        when s.master_account_id = v2.master_account_id then v2.match_rule
        else 'decision'
    end as match_rule
from component c
inner join survivor s on c.component_id = s.component_id
inner join v2 on c.account_id = v2.account_id
