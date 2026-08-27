# Internal archive

Not the user guide. Public usage is the root [`README.md`](../README.md).

| Folder | What |
| --- | --- |
| `real/` `synthetic/` `phase_space/` `solvers/` | Previous scripts (`hist_` prefix). Run only to recover old behavior. |
| [`docs/`](docs/) | Parked maps, glossary, 2025 session notes |
| [`history/`](history/) | Compact changelog + archived topic tables |

**Recover old behavior** from git history or a `hist_` file, not by resurrecting retired folder names (`Dong_func/`, `scripts/` at repo root, `experimental data/`, run-environments).

**Settled conventions**

- Trunks: `run entrance/scripts/{real,synthetic,phase_space,tool}/`
- Session trees: `run entrance/projects/`
- Payloads: `store/` (library), `paper/` (freeze)
- Code: `lib/` (including `core/` and `solvers/`), templates in `config/`, vendor in `3rd party/`
- LDoS kernels: `store/synthetic/ldos/`
- New change rows go in [`history/CHANGELOG.md`](history/CHANGELOG.md)
