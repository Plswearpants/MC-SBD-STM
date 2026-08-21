# Scripts layout

Entrypoints are grouped by stream:

| Folder | Contents |
|--------|----------|
| [`real/`](real/) | Preprocess, real trunks, run-env helpers, postprocessing |
| [`real/viz/`](real/viz/) | Real-data diagnostic / illustration plots |
| [`synthetic/`](synthetic/) | Single-dataset synthetic trunk |
| [`phase_space/`](phase_space/) | Hierarchical dataset gen, parallel run, metrics viz |

Compatibility stubs remain at this folder root for **script** entrypoints (they `run` the relocated file and emit a warning). Function entrypoints `create_run_environment` / `activate_run_environment` live only under `real/` — add that folder to path via `init_sbd` or call them with `run`/`addpath`.

See [`../docs/REPO_STRUCTURE.md`](../docs/REPO_STRUCTURE.md).
