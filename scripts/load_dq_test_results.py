"""Load the latest dbt test results into dq.dq_test_results."""

import csv
import json
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "dbt" / "target"
DATABASE = ROOT / "dbt" / "gtm.duckdb"


def model_name(node: dict) -> str | None:
    attached = node.get("attached_node")
    if attached:
        return attached.split(".")[-1]
    names = [
        node_id.split(".")[-1]
        for node_id in node.get("depends_on", {}).get("nodes", [])
        if node_id.startswith(("model.", "seed."))
    ]
    if len(names) == 1:
        return names[0]
    return None


def main() -> None:
    results = json.loads((TARGET / "run_results.json").read_text())
    manifest = json.loads((TARGET / "manifest.json").read_text())
    run_at = results["metadata"]["generated_at"]
    rows = []
    for result in results["results"]:
        unique_id = result["unique_id"]
        if not unique_id.startswith("test."):
            continue
        node = manifest["nodes"][unique_id]
        rows.append((
            node["name"],
            model_name(node),
            str(node["config"].get("severity", "error")).lower(),
            result["status"],
            result["failures"],
            run_at,
        ))

    con = duckdb.connect(str(DATABASE))
    con.execute("create schema if not exists dq")
    con.execute("drop table if exists dq.dq_test_results")
    con.execute(
        """
        create table dq.dq_test_results (
            name varchar,
            model varchar,
            severity varchar,
            status varchar,
            failures bigint,
            run_at timestamp
        )
        """
    )
    con.executemany(
        "insert into dq.dq_test_results values (?, ?, ?, ?, ?, ?)",
        rows,
    )
    con.close()
    seed = ROOT / "dbt" / "seeds" / "dq_test_results_latest.csv"
    with seed.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name", "model", "severity", "status", "failures", "run_at"])
        w.writerows(rows)


if __name__ == "__main__":
    main()
