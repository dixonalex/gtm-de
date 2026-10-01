ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export GTM_DATA_DIR := $(ROOT)/data

.PHONY: data build fresh all docs ui lab

data:
ifdef AS_OF
	uv run python generator/generate.py --as-of $(AS_OF)
else
	uv run python generator/generate.py
endif

build:
	cd dbt && uv run --project $(ROOT) dbt deps --profiles-dir .
	cd dbt && uv run --project $(ROOT) dbt build --profiles-dir .
	uv run python scripts/load_dq_test_results.py
	cp -f $(ROOT)/dbt/gtm.duckdb $(ROOT)/dbt/gtm_explore.duckdb

fresh:
	cd dbt && uv run --project $(ROOT) dbt source freshness --profiles-dir .

all: data build fresh

docs:
	cd dbt && uv run --project $(ROOT) dbt docs generate --profiles-dir .
	cd dbt && uv run --project $(ROOT) dbt docs serve --profiles-dir .

ui:
	duckdb -ui -cmd "ATTACH '$(ROOT)/dbt/gtm_explore.duckdb' AS gtm (READ_ONLY); USE gtm;"

lab:
	uv run jupyter lab --notebook-dir=notebooks
