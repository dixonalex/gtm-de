with accounts as (
    select
        account_id,
        name,
        website,
        billing_country,
        parent_id,
        created_date
    from {{ ref('stg_salesforce__account') }}
),

normalized as (
    select
        account_id,
        name,
        website,
        billing_country,
        parent_id,
        created_date,
        {{ account_domain_key('website') }} as domain_key,
        {{ account_name_key('name') }} as name_key
    from accounts
),

domain_root as (
    select
        domain_key,
        account_id as root_id
    from normalized
    where domain_key is not null
    qualify row_number() over (
        partition by domain_key
        order by created_date, account_id
    ) = 1
),

-- Domain merge: same website domain, compatible country, and no ParentId link to the survivor.
domain_assigned as (
    select
        n.account_id,
        n.domain_key,
        n.name_key,
        n.created_date,
        case
            when n.domain_key is null then null
            when (
                n.billing_country is null
                or root.billing_country is null
                or n.billing_country = root.billing_country
            )
            and not coalesce(n.parent_id = r.root_id, false)
            and not coalesce(root.parent_id = n.account_id, false)
                then r.root_id
            else n.account_id
        end as domain_master_id
    from normalized n
    left join domain_root r on n.domain_key = r.domain_key
    left join normalized root on r.root_id = root.account_id
),

name_to_domain as (
    select
        name_key,
        min(domain_master_id) as master_account_id
    from domain_assigned
    where domain_key is not null
      and name_key is not null
    group by name_key
),

name_only as (
    select
        n.account_id,
        first_value(n.account_id) over (
            partition by n.name_key
            order by n.created_date, n.account_id
        ) as master_account_id
    from normalized n
    left join name_to_domain nd on n.name_key = nd.name_key
    where n.domain_key is null
      and nd.name_key is null
)

select
    n.account_id,
    case
        when n.domain_key is not null then d.domain_master_id
        when nd.master_account_id is not null then nd.master_account_id
        else no.master_account_id
    end as master_account_id,
    case
        when n.domain_key is not null then 'website'
        else 'name'
    end as match_rule
from normalized n
left join domain_assigned d on n.account_id = d.account_id
left join name_to_domain nd
    on n.domain_key is null
   and n.name_key = nd.name_key
left join name_only no on n.account_id = no.account_id
