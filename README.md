# Quickstart

[![CI](https://github.com/bluelight-dixon/gtm-de/actions/workflows/ci.yml/badge.svg)](https://github.com/bluelight-dixon/gtm-de/actions/workflows/ci.yml)

Prerequisites: [uv](https://docs.astral.sh/uv/) and the DuckDB CLI.

```bash
make all
```

That generates the synthetic data, builds the dbt project, and checks source freshness. Live `make all` generates without `--as-of` and checks freshness; `make AS_OF=YYYY-MM-DD` pins the extract and skips freshness because the pin is intentionally stale.

Explore the warehouse with `make ui` (DuckDB UI), `make lab` (Jupyter in `notebooks/`), or `make docs` (dbt docs). `notebooks/00_connect.ipynb` opens the database read-only.

Explore via gtm_explore.duckdb; it's refreshed on every build and never locks dbt.

DuckDB allows one writer on `dbt/gtm.duckdb`. Close the UI or any other read-write session before `make build` or `make all`.
