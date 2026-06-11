---
name: convert-file
description: 'Convert any data file to another format: CSV, Parquet, JSON, Excel, GeoJSON, and more. Use when the user says "convert to parquet", "save as xlsx", "export as JSON", "make this a CSV", "turn into parquet", or any variation of format-to-format conversion for data files. Also triggers when the user wants to write Parquet, Excel, or other binary formats that Claude cannot produce natively.'
metadata:
  upstream-id: duckdb-skills
  upstream-rev: 7feda8e01e22bc0886c86123f3884947e36d8c69
  upstream-path: convert-file
  upstream-imported: 2026-05-14
---

You are helping the user convert a data file from one format to another using DuckDB.

Work with the input file the user gave. If the user specified an output path,
use it; otherwise pick a sensible default (see Step 1).

## Step 1 — Resolve input and output

**Input**: the file the user gave. If it's a bare filename (no `/`), resolve to a full path with `find "$PWD" -name "<input filename>" -not -path '*/.git/*' 2>/dev/null | head -1`.

**Output**: If the user specified an output path, use it. If not, default to the same stem as the input with a `.parquet` extension (e.g., `data.csv` → `data.parquet`).

Infer the output format from the output file extension:

| Extension | Format clause |
|---|---|
| `.parquet`, `.pq` | *(default, no clause needed)* |
| `.csv` | `(FORMAT csv, HEADER)` |
| `.tsv` | `(FORMAT csv, HEADER, DELIMITER '\t')` |
| `.json` | `(FORMAT json, ARRAY true)` |
| `.jsonl`, `.ndjson` | `(FORMAT json, ARRAY false)` |
| `.xlsx` | `(FORMAT xlsx)` — requires `INSTALL excel; LOAD excel;` |
| `.geojson` | `(FORMAT GDAL, DRIVER 'GeoJSON')` — requires `LOAD spatial;` |
| `.gpkg` | `(FORMAT GDAL, DRIVER 'GPKG')` — requires `LOAD spatial;` |
| `.shp` | `(FORMAT GDAL, DRIVER 'ESRI Shapefile')` — requires `LOAD spatial;` |

## Step 2 — Convert

Run a single DuckDB command. Prepend extension loads as needed based on both the input and output formats.

```bash
duckdb -c "
<EXTENSION_LOADS>
COPY (FROM '<INPUT_PATH>') TO '<OUTPUT_PATH>' <FORMAT_CLAUSE>;
"
```

For remote inputs (`s3://`, `https://`, etc.), prepend the same protocol setup as `read-file`:

| Protocol | Prepend |
|---|---|
| `s3://` | `LOAD httpfs; CREATE SECRET (TYPE S3, PROVIDER credential_chain);` |
| `gs://` / `gcs://` | `LOAD httpfs; CREATE SECRET (TYPE GCS, PROVIDER credential_chain);` |
| `https://` / `http://` | `LOAD httpfs;` |

**If the user mentions partitioning** (e.g., "partition by year"), add `PARTITION_BY (col)` to the format clause. This only works with Parquet and CSV output.

**If the user mentions compression** (e.g., "use zstd"), add `CODEC 'zstd'` for Parquet output.

## Step 3 — Report

On success, report:
- Input file and detected format
- Output file, format, and size (`ls -lh`)
- Row count if quick to compute

On failure:
- **`duckdb: command not found`** → use the `install-duckdb` skill
- **Missing extension** → install it and retry
- **Input parse error** → suggest the user check the input format or use the `read-file` skill first to inspect it
