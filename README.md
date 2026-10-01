# Quickstart

Prerequisites: [uv](https://docs.astral.sh/uv/) and the DuckDB CLI.

```bash
make all
```

That generates the synthetic data, builds the dbt project, and checks source freshness.

Explore the warehouse with `make ui` (DuckDB UI), `make lab` (Jupyter in `notebooks/`), or `make docs` (dbt docs). `notebooks/00_connect.ipynb` opens the database read-only.

DuckDB allows one writer on `dbt/gtm.duckdb`. Close the UI or any other read-write session before `make build` or `make all`.
