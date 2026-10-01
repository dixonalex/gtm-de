# GTM dashboard

Evidence pages over the dbt marts. From the repo root, `make dash` builds the warehouse, refreshes sources from `dbt/gtm_explore.duckdb`, and serves the site.

`GITHUB_REPO` is optional. When it is set at `npm run sources` time, the review queue shows a Decide link to that repo's account-match issue form.
