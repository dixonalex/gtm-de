with accounts as (
    select
        account_id,
        name,
        website,
        created_date
    from {{ ref('stg_salesforce__account') }}
),

normalized as (
    select
        account_id,
        created_date,
        nullif(
            split_part(
                regexp_replace(
                    regexp_replace(lower(website), '^https?://', ''),
                    '^www\.',
                    ''
                ),
                '/',
                1
            ),
            ''
        ) as domain_key,
        nullif(
            regexp_replace(
                trim(
                    regexp_replace(
                        replace(
                            regexp_replace(lower(name), '\s*\([^)]*\)', '', 'g'),
                            '.',
                            ''
                        ),
                        '[^a-z0-9]+',
                        ' ',
                        'g'
                    )
                ),
                '(\s+(incorporated|holdings|group|corp|gmbh|llc|ltd|inc|kk|co))+$',
                ''
            ),
            ''
        ) as name_key
    from accounts
),

domain_ranked as (
    select
        domain_key,
        account_id as master_account_id,
        row_number() over (
            partition by domain_key
            order by created_date, account_id
        ) as rn
    from normalized
    where domain_key is not null
),

domain_master as (
    select domain_key, master_account_id
    from domain_ranked
    where rn = 1
),

name_to_domain as (
    select
        n.name_key,
        min(dm.master_account_id) as master_account_id
    from normalized n
    inner join domain_master dm on n.domain_key = dm.domain_key
    where n.name_key is not null
    group by n.name_key
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
        when n.domain_key is not null then dm.master_account_id
        when nd.master_account_id is not null then nd.master_account_id
        else no.master_account_id
    end as master_account_id,
    case
        when n.domain_key is not null then 'website'
        else 'name'
    end as match_rule
from normalized n
left join domain_master dm on n.domain_key = dm.domain_key
left join name_to_domain nd
    on n.domain_key is null
   and n.name_key = nd.name_key
left join name_only no on n.account_id = no.account_id
