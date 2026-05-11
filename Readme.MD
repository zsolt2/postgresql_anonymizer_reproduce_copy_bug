# `postgresql_anonymizer` — `MASKED` role COPY mangles column identifiers

## Summary

When a role labelled `MASKED` (with `anon.transparent_dynamic_masking = true`)
runs `COPY <table> (<columns>) TO …`, the anonymizer's column-rewrite step
produces an identifier that doesn't match the real column. The same statements
succeed unchanged for the table owner and as `SELECT` queries for the masked
role, so the SQL on the wire is valid — the bug is in the rewrite.

As a downstream consequence, `pg_dump --data-only` against any table containing
one of the broken identifier shapes fails when the dump is run as the masked
role.


## Environment

- PostgreSQL 17.8 (Debian 17.8-1.pgdg13+1)
- `anon` 2.0.0-3.0.13
- Base image: `registry.gitlab.com/dalibo/postgresql_anonymizer:stable`



## Repository layout

| File | Purpose |
|---|---|
| [001-repro.sql](001-repro.sql) | Creates `test_db`, the `test_schema.test_table` with 14 edge-case column names, and a `MASKED` role. Loaded by the postgres image's entrypoint. |
| [test.sh](test.sh) | Iterates the column list and runs each as a COPY for `table_owner`, then a SELECT for `anon_user`, then a COPY for `anon_user`, then `pg_dump` once at the end. |
| [Dockerfile](Dockerfile) | Bakes the SQL + test script into the stable `anon` image. |
| [run-test.sh](run-test.sh) | Builds the image, starts a container, waits until init scripts have applied (by polling a TCP query against `test_db`), and runs `test.sh`. |

## Reproduce

```bash
./run-test.sh
```

The readiness gate is a real TCP query against `test_db` — it only returns 0
once the entrypoint has restarted postgres on TCP *and* `001-repro.sql` has
applied, so there is no `sleep` race.

## Observed behaviour

- `table_owner` COPY: **all 7 columns succeed.**
- `anon_user` SELECT: **all 7 columns succeed** (the masking SELECT path
  quotes identifiers correctly).
- `anon_user` COPY:  **all 7 columns fail**

| Column (SQL on wire, from PostgreSQL's `LINE 1:` echo) | Server response | What the rewrite produced |
|---|---|---|
| `"Example Column"` | `column "Example\ Column" does not exist` | space → `\<space>` |
| `"col with  multiple   spaces"` | `column "col\ with\ \ multiple\ \ \ spaces" does not exist` | every space → `\<space>` |
| `" leading_space"` | `column "\ leading_space" does not exist` | leading space → `\<space>` |
| `"trailing_space "` | `column "trailing_space\ " does not exist` | trailing space → `\<space>` |
| `"123abc"` | `column "\123abc" does not exist` | leading digit → `\123` |
| `"col""with""quotes"` | `syntax error at or near "with"` | embedded `""` collapsed to `"`, identifier closes early |

### `pg_dump` impact

`pg_dump -U anon_user --data-only -t test_schema.test_table` fails:

```
pg_dump: error: query failed: ERROR:  syntax error at or near "with"
LINE 1: ...le_column, "Example Column", "MixedCase", "col!@#$%", "naïve...
                                                             ^
pg_dump: detail: Query was: COPY test_schema.test_table (id, example_column, "Example Column", "MixedCase", "col!@#$%", "naïve_café", "col""with""quotes", "select", "col.with.dot", "col-with-dash", "col'with'apostrophe", "123abc", "col with  multiple   spaces", " leading_space", "trailing_space ") TO stdout;
```

Any table that contains a column matching the embedded-`""` shape cannot be
logically dumped by a `MASKED` role. The other broken shapes presumably fail
the same way when present.