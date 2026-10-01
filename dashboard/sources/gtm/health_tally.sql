select
    count(*) as tests,
    count(*) filter (where status = 'pass') as pass_n,
    count(*) filter (where status in ('warn', 'fail', 'error') and severity = 'warn') as warn_n,
    count(*) filter (where status in ('fail', 'error') and severity = 'error') as error_n
from seeds.dq_test_results_latest
