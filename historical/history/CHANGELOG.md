# Changelog

Append a row when something is retired, moved, or its caller path changes.
Do not rewrite earlier rows unless correcting an error.

Columns: `Date`, `Type`, `Component`, `Change`, `Caller Migration`, `Legacy Recovery`.

Older topic-by-topic tables (repo reorg, payload move, per-trunk bugfixes) sit in [`archive/`](archive/). Line-by-line payload MOVE log: [`payload_migration_log.txt`](payload_migration_log.txt).

| Date | Type | Component | Change | Caller Migration | Legacy Recovery |
| --- | --- | --- | --- | --- | --- |
| 2026-08-27 | Update | `paper freeze gitignore` | Stop tracking `paper/**/*.mat` (GitHub 100 MB limit; several files 0.3–3.7 GB). Movies and `plotting_paper.m` remain tracked. Files stay on disk. | `.gitignore`, `paper/README.md` | Files remain at `paper/figures/Main Figures/`; recover ignore exception from git history before this change. |
| 2026-08-26 | Update | `docs collapse` | Public guide is root `README.md` only. Living maps/glossary/script-standard parked under `historical/docs/`. Per-topic history tables moved to `historical/history/archive/`; this file is the living log. | `README.md`, `docs/README.md`, `historical/README.md`, `historical/history/CHANGELOG.md`, `.cursor/rules/history-update-log-table.mdc`; comments in `synthetic_data.m`, `loadRealDataset.m`, `lib/solvers/README.md`, `run entrance/scripts/README.md` | Restore parked files from `historical/docs/` and `historical/history/archive/`. |
