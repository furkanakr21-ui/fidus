# TEFAS/BEFAS Ingest Worker

Server-side worker for official TEFAS market data. The Flutter app must read
fund data from Supabase and never call external fund endpoints directly.

## Required Environment

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## Optional Environment

- `TEFAS_TARGET_DATE` in `YYYY-MM-DD` format
- `TEFAS_LOOKBACK_DAYS` default `7`
- `TEFAS_REQUEST_INTERVAL_SECONDS` default `10`
- `TEFAS_PAGE_SIZE` default `250`
- `TEFAS_MAX_PAGES` optional smoke-test page cap; unset for production
- `TEFAS_FAMILIES` optional comma-separated family filter such as `YAT,EMK`
- `TEFAS_SKIP_VALIDATION` optional smoke-test bypass; keep unset for production
- `TEFAS_DRY_RUN` set to `true` to fetch and validate without publishing

The worker warms up each TEFAS session before POST requests and rejects only
technical failures such as empty/invalid TEFAS responses or duplicate codes in
the same TEFAS/BEFAS bucket. Publishing is incremental: rows returned by TEFAS
are upserted, rows missing from the current run are left unchanged, and missing
or zero prices never overwrite the last known valid price.

## Run

```sh
docker build -t fidus-tefas-ingest workers/tefas_ingest
docker run --rm \
  -e SUPABASE_URL=... \
  -e SUPABASE_SERVICE_ROLE_KEY=... \
  fidus-tefas-ingest
```

Run this worker from a server-side scheduler only. Do not invoke it from the
Flutter client.
