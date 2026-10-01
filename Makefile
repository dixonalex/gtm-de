ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export GTM_DATA_DIR := $(ROOT)/data

# AS_OF unset is a live extract. make AS_OF=YYYY-MM-DD pins the generator.
.PHONY: data build fresh all docs ui lab dash story-check page-check

data:
ifdef AS_OF
	uv run python generator/generate.py --as-of $(AS_OF)
else
	uv run python generator/generate.py
endif

build:
	cd dbt && uv run --project $(ROOT) dbt deps --profiles-dir .
	uv run python scripts/derive_story_seeds.py --phase prepare
	# The story build has one expected test error. Record it, then refresh plan-backed models.
	-cd dbt && uv run --project $(ROOT) dbt build --profiles-dir .
	uv run python scripts/load_dq_test_results.py
	uv run python scripts/derive_story_seeds.py --phase plans
	cd dbt && uv run --project $(ROOT) dbt seed --full-refresh --profiles-dir . --select plan_monthly quota_quarterly forecast_call_weekly dq_test_results_latest
	cd dbt && uv run --project $(ROOT) dbt run --profiles-dir . --select fct_arr_plan fct_forecast_call dq_model_health fct_billings_by_currency
	cp -f $(ROOT)/dbt/gtm.duckdb $(ROOT)/dbt/gtm_explore.duckdb

story-check:
	uv run python scripts/story_check.py

page-check:
	uv run python scripts/page_check.py

fresh:
ifdef AS_OF
	@echo "freshness skipped: pinned extract (AS_OF=$(AS_OF)) is intentionally stale"
else
	cd dbt && uv run --project $(ROOT) dbt source freshness --profiles-dir .
endif

all: data build fresh

docs:
	cd dbt && uv run --project $(ROOT) dbt docs generate --profiles-dir .
	cd dbt && uv run --project $(ROOT) dbt docs serve --profiles-dir .

ui:
	duckdb -ui -cmd "ATTACH '$(ROOT)/dbt/gtm_explore.duckdb' AS gtm (READ_ONLY); USE gtm;"

lab:
	uv run jupyter lab --notebook-dir=notebooks

dash: build
	cd dashboard && npm install
	cd dashboard && npm run sources
	cd dashboard && npm run dev
