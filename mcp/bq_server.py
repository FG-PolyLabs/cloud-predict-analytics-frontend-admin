#!/usr/bin/env python3
"""
bq_server.py — MCP server for querying the fg-polylabs BigQuery weather dataset.

Tables:
  fg-polylabs.weather.tracked_cities
  fg-polylabs.weather.polymarket_snapshots
  fg-polylabs.weather.meteo_gfs_forecasts
  fg-polylabs.weather.meteo_ecmwf_forecasts
  fg-polylabs.weather.meteo_icon_forecasts

Auth: Application Default Credentials — run `gcloud auth application-default login` once.
"""

import re
from google.cloud import bigquery
from mcp.server.fastmcp import FastMCP

PROJECT = "fg-polylabs"
DATASET = "weather"
MAX_ROWS = 200

TABLES = {
    "tracked_cities": (
        "Cities being tracked. "
        "Fields: city, source, display_name, timezone, active, added_date, notes."
    ),
    "polymarket_snapshots": (
        "Polymarket prediction market price snapshots. "
        "Fields: city, date, timestamp, temp_threshold, yes_cost, no_cost, "
        "best_bid, best_ask, spread, volume_24h, volume_total, liquidity, "
        "event_slug, market_end_date."
    ),
    "meteo_gfs_forecasts": (
        "Open-Meteo GFS ensemble weather forecasts (4 runs/day: 00z/06z/12z/18z). "
        "Fields: city, target_date, forecast_date, lead_days, predicted_max_temp_c, "
        "temp_std_dev_c, skewness, p10_temp_c, p90_temp_c, member_count, member_temps, "
        "model, model_run_at, actual_max_temp_c, error_c."
    ),
    "meteo_ecmwf_forecasts": (
        "Open-Meteo ECMWF IFS ensemble weather forecasts (2 runs/day: 00z/12z). "
        "Fields: city, target_date, forecast_date, lead_days, predicted_max_temp_c, "
        "temp_std_dev_c, skewness, p10_temp_c, p90_temp_c, member_count, member_temps, "
        "model, model_run_at, actual_max_temp_c, error_c."
    ),
    "meteo_icon_forecasts": (
        "Open-Meteo DWD ICON seamless ensemble weather forecasts (4 runs/day: 00z/06z/12z/18z, ~40 members). "
        "Fields: city, target_date, forecast_date, lead_days, predicted_max_temp_c, "
        "temp_std_dev_c, skewness, p10_temp_c, p90_temp_c, member_count, member_temps, "
        "model, model_run_at, actual_max_temp_c, error_c."
    ),
    "nbm_noaa_forecasts": (
        "NOAA NBM (National Blend of Models) daily max temperature forecasts from GRIB2 (US cities only: chicago, dallas, miami, nyc). "
        "Provides mean + ensemble std dev (no raw members). Percentiles derived from normal distribution. "
        "Fields: city, target_date, forecast_date, lead_days, tmax_mean_c, tmax_spread_c, "
        "tmax_p10_c, tmax_p25_c, tmax_p50_c, tmax_p75_c, tmax_p90_c, model, model_run_at, "
        "actual_max_temp_c, error_c."
    ),
}

_DML = re.compile(
    r"\b(INSERT|UPDATE|DELETE|TRUNCATE|DROP|CREATE|ALTER|MERGE|REPLACE)\b",
    re.IGNORECASE,
)

mcp = FastMCP("bigquery-weather")
_client: bigquery.Client | None = None


def client() -> bigquery.Client:
    global _client
    if _client is None:
        _client = bigquery.Client(project=PROJECT)
    return _client


@mcp.tool()
def list_tables() -> str:
    """List the available BigQuery tables in the weather dataset."""
    lines = [f"Project: {PROJECT}  Dataset: {DATASET}\n"]
    for name, desc in TABLES.items():
        lines.append(f"{name}\n  {desc}\n")
    return "\n".join(lines)


@mcp.tool()
def get_schema(table_name: str) -> str:
    """
    Return the schema (column names, types, row count) for a table.

    Args:
        table_name: tracked_cities | polymarket_snapshots | meteo_gfs_forecasts | meteo_ecmwf_forecasts | meteo_icon_forecasts | nbm_noaa_forecasts
    """
    if table_name not in TABLES:
        return f"Unknown table '{table_name}'. Available: {', '.join(TABLES)}"
    tbl = client().get_table(f"{PROJECT}.{DATASET}.{table_name}")
    lines = [f"{table_name}  ({tbl.num_rows:,} rows)\n"]
    for f in tbl.schema:
        mode = f" [{f.mode}]" if f.mode not in ("NULLABLE", "") else ""
        lines.append(f"  {f.name:<30} {f.field_type}{mode}")
    return "\n".join(lines)


@mcp.tool()
def query(sql: str, max_rows: int = 100) -> str:
    """
    Run a read-only SQL query against the BigQuery weather dataset.

    Reference tables as `fg-polylabs.weather.<table>` or `weather.<table>`.
    DML (INSERT/UPDATE/DELETE/etc.) is blocked.

    Args:
        sql:      Standard SQL SELECT statement
        max_rows: Rows to return (default 100, capped at 200)
    """
    if _DML.search(sql):
        return "Error: DML statements are not permitted — SELECT only."

    max_rows = min(max(1, max_rows), MAX_ROWS)
    job_config = bigquery.QueryJobConfig(maximum_bytes_billed=50 * 1024 * 1024)
    result = client().query(sql, job_config=job_config).result()

    rows = []
    for row in result:
        rows.append(dict(row))
        if len(rows) >= max_rows:
            break

    if not rows:
        return "Query returned 0 rows."

    headers = list(rows[0].keys())
    widths = {h: len(h) for h in headers}
    for row in rows:
        for h in headers:
            widths[h] = max(widths[h], len(str(row.get(h, ""))))

    header_line = "  ".join(h.ljust(widths[h]) for h in headers)
    sep = "  ".join("-" * widths[h] for h in headers)
    data_lines = [
        "  ".join(str(row.get(h, "")).ljust(widths[h]) for h in headers)
        for row in rows
    ]

    truncation_note = f"  (capped at {max_rows})" if len(rows) == max_rows else ""
    return "\n".join([header_line, sep, *data_lines]) + f"\n\n{len(rows)} rows{truncation_note}"


if __name__ == "__main__":
    mcp.run()
