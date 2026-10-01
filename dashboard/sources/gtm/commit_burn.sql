select month_end, active_commits, commit_usd, share_consumed, straight_line
from marts.fct_commit_consumption
order by month_end
