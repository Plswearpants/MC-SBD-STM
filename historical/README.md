# Internal archive

Not the user guide. Public usage is the root [`README.md`](../README.md).

| Folder | What | On GitHub? |
| --- | --- | --- |
| `real/` `synthetic/` `phase_space/` `solvers/` | Previous scripts (`hist_` prefix). Run only to recover old behavior. | Yes |
| [`docs/`](docs/) | Parked maps, glossary, session notes | Local only |
| [`history/archive/`](history/archive/) | Topic-split reorg / retirement tables | Local only |
| [`history/CHANGELOG.md`](history/CHANGELOG.md) | Living append-only change log | Yes |

**Recover old behavior** from git history or a `hist_` file, not by resurrecting retired folder names (`Dong_func/`, `scripts/` at repo root, `experimental data/`, run-environments).

**Settled conventions**

- Trunks: `run entrance/scripts/{real,synthetic,phase_space,tool}/`
- Session trees: `run entrance/projects/`
- Payloads: `store/` (library), `paper/` (freeze)
- Code: `lib/` (including `core/` and `solvers/`), vendor in `3rd party/`
- Solver `.mat` templates: local under `config/` (created by `init_sbd`)
- LDoS kernels: `store/synthetic/ldos/`
- New change rows go in [`history/CHANGELOG.md`](history/CHANGELOG.md)
