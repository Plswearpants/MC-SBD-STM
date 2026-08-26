# MC-SBD-STM Repository Structure

Living map of functional streams, canonical entrypoints, and conventions.
Update this file whenever the on-disk layout changes (keep in sync with
[`REPO_STRUCTURE_DAG.md`](REPO_STRUCTURE_DAG.md) and
[`../history/repo_reorg.md`](../history/repo_reorg.md)).

## Functional streams

| Stream | Purpose | Artifact home |
| --- | --- | --- |
| **Real data** | Preprocess STM measurements → MC-SBD → paper/result viz | `projects/real_<ts>/`, `examples/data/` |
| **Synthetic single-dataset** | One config → full MCSBD trunk + project logging | `projects/synthetic_<ts>/` |
| **Synthetic parameter-space** | Dataset grid → parallel SBD → phase-space heatmaps | `artifacts/synthetic/` (canonical); legacy `examples/results/` |
| **Shared core** | Solvers, domain lib, config, utils | N/A (source only) |

## Naming convention

- Official trunks live only under `scripts/{real,synthetic,phase_space}/` (no `RUN_` prefix).
- **`hist_` prefix** marks a previous script. Those files live under `historical/`, not in the live script folders.
- There are no compatibility stubs at `scripts/*.m`.

## Happy paths

### Real data — two ways (both kept)

**Split (official, usual):** preprocessing is slow, interactive, and reused across many decomposition runs.

1. `scripts/real/real_preprocess.m` — `.3ds` → cleaned volume `Y`
2. `scripts/real/real_block.m` — `Y` → kernels / activations / figures
3. Paper viz: `examples/data/ZrSiTe/result/plotting_paper.m` (+ other real viz listed below)

**Combined (retired, still available):** one script from raw `.3ds` through decomposition.

1. `historical/real/hist_run_real_data.m`

| Role | Script | Status |
| --- | --- | --- |
| Official preprocess | `scripts/real/real_preprocess.m` | Official (split path, first half) |
| Official block run | `scripts/real/real_block.m` | Official (split path, second half) |
| Combined raw-to-result | `historical/real/hist_run_real_data.m` | Retired (`hist_`); keep as the second way |
| Previous block script | `historical/real/hist_MCSBD_block_realdata1.m` | Retired; R-series experiment blocks live here |
| Previous preprocess | `historical/real/hist_preprocess.m` | Retired |
| Previous postprocess | `historical/real/hist_postprocessing.m` | Retired |
| 2D preprocess helper | `scripts/real/preprocess_2d.m` | Live specialized helper (not a trunk) |

### Synthetic single-dataset

1. `scripts/synthetic/synthetic_data.m` — generate one dataset, decompose, visualize, save under `projects/`
2. Minimal 2D demo: `examples/simple_MCSBD_example.m` — load frozen `examples/example_data/simple_mcsbd_2d/` (or generate + WS01A freeze) → `MCSBD_synthetic` with the DS01A parameter set. No session log / project folder.
3. Previous inline trunk: `historical/synthetic/hist_MCSBD_block_synthetic.m` (retired)

### Synthetic parameter-space (dataset grid)

1. `scripts/phase_space/properGen_hierarchical.m` — SNR × density × side-length-ratio grid → `artifacts/synthetic/datasets/`
2. `scripts/phase_space/run_parallel_dataset.m` — many **datasets**, one fixed solver combo. The worker call is `SBD_test_multi_parallel` (`solvers/SBD_test_multi_parallel.m`) inside a `parfor`.
3. `scripts/phase_space/visualize_dataset_metrics.m` + `lib/phase_space/` — one S0 control panel for the recipe; each B/V `%%` cell is a complete MATLAB section (Run Section works). Plot-only: set every `cfg.build.*` false, keep `metrics` in the workspace, run S0 then the V cell.

**Solver-param sweeps** (`lambda1` × `mini_loop`) live in the retired runner
`historical/synthetic/run_parallel_tests.m` — not the primary phase-space path.

## Trial record: project folder + log (not run-env)

Run-environments (`runs/<name>/`, `create_run_environment`) are **retired**. Existing `runs/zrsite_*` folders are leftover trials; helpers live as `historical/real/hist_create_run_environment.m` / `hist_activate_run_environment.m`.

**Do not rely on `cd` into a special folder as the trial identity.** Official trunks write the session log into a timestamped **project folder**, independent of most cwd clutter:

1. Pick a project root: set `params.project.root = pwd` in the PRESETS, or leave it empty and choose a directory in the UI (the dialog starts at `pwd`).
2. The trunk creates `<root>/real_<yyyymmdd_HHMMSS>/` (synthetic: `synthetic_<ts>/`).
3. `logUsedBlocks` appends one line per executed block to `<project>/<session>_LOGfile.txt` (`DATE`, `BLOCK`, `COMMENT`). The comment is where presets and interactive choices are recorded.
4. Checkpoints / handoff `.mat` files land in that same project folder.

For the split real path, set `params.project.existing_path` in `real_block.m` to the project printed by `real_preprocess.m` so preprocess and decompose share one log tree.

Solver tunables are written to `config/runtime_tunables/` as
`Xsolve_config_tunable_<log.file>.mat` and `Asolve_config_tunable_<log.file>.mat`.
The trial log records a `CFG01` line with that directory and those names, so the
`.mat` suffix matches the log stem.

## Real-data visualization set

| Script | Role |
| --- | --- |
| `examples/data/ZrSiTe/result/plotting_paper.m` | Publication figures |
| `lib/visualizeRealResult.m` | Per-slice reconstruction panels |
| `lib/wrapper/visualizeRealRun.m` | Post-run movies across slices |
| `historical/real/hist_postprocessing.m` | Retired post-run kernel/QPI display |
| `scripts/real/viz/directional_mask_waterfall.m` | Directional QPI mask diagnostic |
| `scripts/real/viz/break_degeneracy_illustration_plot.m` | Degeneracy illustration |
| `utils/show_results.m` | Compact Y / reconstruction / A / X grid |

## Directory layout (target)

```
MC-SBD-STM/
  docs/REPO_STRUCTURE.md          # this file
  docs/REPO_STRUCTURE_DAG.md      # mermaid DAG
  history/repo_reorg.md           # migration table
  scripts/
    real/                         # real_preprocess, real_block, preprocess_2d, viz/
    synthetic/                    # synthetic_data
    phase_space/                  # hierarchical gen, parallel run, metrics viz
  solvers/                        # live APIs: MC_SBD, MCSBD_*_modified/synthetic, SBD, SBD_test_multi_parallel
  lib/                            # domain library (formerly Dong_func)
    wrapper/
    phase_space/
  core/  utils/  config/
  vendor/                         # slanCM, imshow3D, mat2im
  runs/                           # leftover real trials (retired run-env; do not use)
  projects/                       # real_<ts>/ and synthetic_<ts>/ project trees
  artifacts/synthetic/            # batch datasets + parallel results
  historical/                     # hist_ previous scripts + older retirements
    solvers/                      # hist_ experimental / retired solvers
  examples/                       # thin demos + sample data (simple_SBD_example, simple_MCSBD_example)
```

## Config policy

1. **Immutable templates** only: `config/Xsolve_config.mat`, `config/Asolve_config.mat`.
2. **Tunables** are written under `config/runtime_tunables/` (never cwd). When a trunk has called `registerTunableRun`, names are `Xsolve_config_tunable_<log.file>.mat` and `Asolve_config_tunable_<log.file>.mat`.
3. `resolve_tunable_config` prefers the suffixed trial copy, then an unsuffixed session copy, then `config/` templates.
4. Parallel workers that pass an absolute in-place tunable path (3-arg `update_config`) are unchanged.

## Path bootstrap

`init_sbd` adds: repo root, `core/`, `utils/`, `config/`, `lib/` (and subdirs), `solvers/`, `historical/solvers/`, `vendor/`, `colormap/`, and `scripts/{real,synthetic,phase_space}/`. Call it from the repo (or any subfolder). `bootstrap_init_sbd` is an Editor-temp-safe wrapper that locates `init_sbd.m` and runs it; trunks currently inline the same walk.

## Related docs

- [`script_standardization.md`](script_standardization.md) — block IDs, checkpoints, logging
- [`FOLDER_STRUCTURE_ANALYSIS.md`](FOLDER_STRUCTURE_ANALYSIS.md) — nested project layout proposal
- [`../history/`](../history/) — topic-specific update/deprecation tables
- [`../history/simple_mcsbd_example_updates.md`](../history/simple_mcsbd_example_updates.md) — freeze/load path for the 2D MCSBD example
- [`../history/solvers_retirement.md`](../history/solvers_retirement.md) — dead solver deletes and `hist_` experimental solvers
