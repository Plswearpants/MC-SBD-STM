# MC-SBD-STM Repository Structure

Living map of functional streams, canonical entrypoints, and conventions.
Update this file whenever the on-disk layout changes (keep in sync with
[`REPO_STRUCTURE_DAG.md`](REPO_STRUCTURE_DAG.md) and
[`../historical/history/repo_reorg.md`](../historical/history/repo_reorg.md)).
Catalog of this folder: [`README.md`](README.md).

## Functional streams

| Stream | Purpose | Library | Session |
| --- | --- | --- | --- |
| **Real data** | Preprocess STM measurements → MC-SBD → paper viz | `store/real/` (`processed/<Material>_<MMDD>/`, `runs/<Material>_<MMDD>/`) | `projects/real_<ts>/` |
| **Synthetic single-dataset** | One config → full MCSBD trunk + project logging | `store/synthetic/` | `projects/synthetic_<ts>/` |
| **Synthetic parameter-space** | Dataset grid → parallel SBD → heatmaps | `store/phase_space/` | (grid files are the library) |
| **Paper freeze** | Hard-linked snapshot of what the manuscript used | `paper/freeze/{real,phase_space}/` | n/a |
| **Shared core** | Solvers, domain lib, config, utils | N/A (source only) | n/a |

## Naming convention

- Official trunks live only under `run entrance/scripts/{real,synthetic,phase_space}/`.
- **`hist_` prefix** marks a previous script. Those files live under `historical/`, not in the live script folders.
- There are no compatibility stubs at `scripts/*.m`.

## Payload layers (`store` / `paper` / `projects`)

| Layer | Folder | Job |
| --- | --- | --- |
| Library | `store/` | Named, reusable. Real `Y` and runs are indexed as `<Material>_<MMDD>` (e.g. `ZrSiTe_0528`). Raw `.3ds` is under `store/real/raw/<sample>/`. Map: [`store/README.md`](../store/README.md). |
| Freeze | `paper/` | Manuscript set. Hard links into `store/` (same bytes, two names). `plotting_paper.m` S01/S02 start in `paper/freeze/`. |
| Session | `run entrance/projects/` | One sitting: log + checkpoints. Promote keepers into `store/`. |

## Happy paths

### Real data — two ways (both kept)

**Split (official, usual):** preprocessing is slow, interactive, and reused across many decomposition runs.

1. `run entrance/scripts/real/real_preprocess.m` — `.3ds` → cleaned volume `Y` (session + promote to `store/real/processed/<Material>_<MMDD>/`)
2. `run entrance/scripts/real/real_block.m` — `Y` from that processed folder → kernels / activations / figures
3. Paper viz: `paper/figures/Main Figures/plotting_paper.m` (reads `paper/freeze/`)

**Combined (retired, still available):** `historical/real/hist_run_real_data.m`.

| Role | Script | Status |
| --- | --- | --- |
| Official preprocess | `run entrance/scripts/real/real_preprocess.m` | Official (split path, first half) |
| Official block run | `run entrance/scripts/real/real_block.m` | Official (split path, second half) |
| Combined raw-to-result | `historical/real/hist_run_real_data.m` | Retired (`hist_`) |
| Previous block script | `historical/real/hist_MCSBD_block_realdata1.m` | Retired |
| Previous preprocess | `historical/real/hist_preprocess.m` | Retired |
| Previous postprocess | `historical/real/hist_postprocessing.m` | Retired |
| 2D preprocess helper | `run entrance/scripts/real/preprocess_2d.m` | Live specialized helper (not a trunk) |

### Synthetic single-dataset

1. `run entrance/scripts/synthetic/synthetic_data.m` — generate one dataset, decompose, visualize, save under `run entrance/projects/`. LDoS kernels come from `store/synthetic/ldos/`.
2. Minimal 2D demo: `examples/simple_MCSBD_example.m` — load frozen `examples/example_data/simple_mcsbd_2d/` (or generate + WS01A freeze) → `MCSBD_synthetic` with the DS01A parameter set. No session log / project folder.
3. Previous inline trunk: `historical/synthetic/hist_MCSBD_block_synthetic.m` (retired)

### Synthetic parameter-space (dataset grid)

1. `run entrance/scripts/phase_space/properGen_hierarchical.m` — SNR × density × side-length-ratio grid → `store/phase_space/datasets/`
2. `run entrance/scripts/phase_space/run_parallel_dataset.m` — many **datasets**, one fixed solver combo. Worker: `SBD_test_multi_parallel` inside a `parfor`. Writes to `store/phase_space/parallel_runs/<dataset_stem>/`.
3. `run entrance/scripts/phase_space/visualize_dataset_metrics.m` + `lib/phase_space/` — S0 recipe panel; each B/V `%%` cell is a complete MATLAB section.

**Solver-param sweeps** (`lambda1` × `mini_loop`) live in the retired runner
`historical/synthetic/run_parallel_tests.m`.

## Trial record: project folder + log (not run-env)

Run-environments are **retired**. Helpers: `historical/real/hist_create_run_environment.m` / `hist_activate_run_environment.m`.

Official trunks write the session log into a timestamped **project folder**:

1. Set `params.project.root = pwd` or pick a directory in the UI (defaults to `run entrance/projects/`).
2. The trunk creates `<root>/real_<yyyymmdd_HHMMSS>/` (synthetic: `synthetic_<ts>/`).
3. `logUsedBlocks` appends to `<project>/<session>_LOGfile.txt` (`DATE`, `BLOCK`, `COMMENT`).
4. Checkpoints / handoff `.mat` files land in that same project folder.

For the split real path, set `params.project.existing_path` in `real_block.m` to the project printed by `real_preprocess.m`.

Solver tunables go to `config/runtime_tunables/` as
`Xsolve_config_tunable_<log.file>.mat` and `Asolve_config_tunable_<log.file>.mat`.

## Real-data visualization set

| Script | Role |
| --- | --- |
| `paper/figures/Main Figures/plotting_paper.m` | Publication figures (freeze: `paper/freeze/`) |
| `lib/visualizeRealResult.m` | Per-slice reconstruction panels |
| `lib/wrapper/visualizeRealRun.m` | Post-run movies across slices |
| `historical/real/hist_postprocessing.m` | Retired post-run kernel/QPI display |
| `utils/show_results.m` | Compact Y / reconstruction / A / X grid |

## Directory layout

```
MC-SBD-STM/
  docs/                           # living maps (see docs/README.md)
  historical/
    history/                      # append-only update tables
    docs/                         # parked session notes
    real|synthetic|phase_space|solvers/
  run entrance/scripts/{real,synthetic,phase_space,tool}/
  lib/  config/  3rd party/
  store/                          # reusable library (see store/README.md)
  paper/                          # freeze + figures + plotting_paper.m
  run entrance/projects/          # session trees + logs only
  examples/                       # thin demos + bundled 2D freeze
```

## Config policy

1. **Immutable templates** only: `config/Xsolve_config.mat`, `config/Asolve_config.mat`.
2. **Tunables** under `config/runtime_tunables/` (never cwd). Suffixed when a trunk has called `registerTunableRun`.
3. `resolve_tunable_config` prefers the suffixed trial copy, then an unsuffixed session copy, then `config/` templates.
4. Parallel workers that pass an absolute in-place tunable path (3-arg `update_config`) are unchanged.

## Path bootstrap

`init_sbd` adds: repo root, `config/`, `lib/` (and subdirs, with `lib/utils` first), `historical/solvers/`, `3rd party/`, and `run entrance/scripts/{real,synthetic,phase_space,tool}/`. Missing folders are skipped (no warning). Call it from the repo (or any subfolder). `bootstrap_init_sbd` is the Editor-temp-safe locator; trunks inline the same walk.

## Related docs

- [`script_standardization.md`](script_standardization.md) — block IDs, checkpoints, logging
- [`parameter_glossary.md`](parameter_glossary.md) — synthetic-trunk parameter meanings
- [`../historical/history/`](../historical/history/) — topic-specific update/deprecation tables
- [`../historical/docs/`](../historical/docs/) — parked session notes
