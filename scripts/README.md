# Scripts layout

Entrypoints are grouped by stream. Previous scripts live under `historical/`
with a `hist_` prefix.

| Folder | Contents |
|--------|----------|
| [`real/`](real/) | Official split trunks (`real_preprocess`, `real_block`); `preprocess_2d`; `viz/` |
| [`real/viz/`](real/viz/) | Real-data diagnostic / illustration plots |
| [`synthetic/`](synthetic/) | Official `synthetic_data` |
| [`phase_space/`](phase_space/) | `properGen_hierarchical` → `run_parallel_dataset` (`SBD_test_multi_parallel`) → `visualize_dataset_metrics` |

See [`../docs/REPO_STRUCTURE.md`](../docs/REPO_STRUCTURE.md).
