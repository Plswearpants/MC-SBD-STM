# MT-SBD-STM Repository Structure

Living map of functional streams, canonical entrypoints, and conventions.
Update this file whenever the on-disk layout changes (keep in sync with
`[REPO_STRUCTURE_DAG.md](REPO_STRUCTURE_DAG.md)` and
`[../history/repo_reorg.md](../history/repo_reorg.md)`).

## Functional streams


| Stream                        | Purpose                                                 | Artifact home                                                  |
| ----------------------------- | ------------------------------------------------------- | -------------------------------------------------------------- |
| **Real data**                 | Preprocess STM measurements → MT-SBD → paper/result viz | `runs/<env>/`, `examples/data/`                                |
| **Synthetic single-dataset**  | One config → full MCSBD trunk + project logging         | `projects/synthetic_<ts>/`                                     |
| **Synthetic parameter-space** | Dataset grid → parallel SBD → phase-space heatmaps      | `artifacts/synthetic/` (canonical); legacy `examples/results/` |
| **Shared core**               | Solvers, domain lib, config, utils                      | N/A (source only)                                              |




## Happy paths



### Real data

1. `scripts/real/preprocess.m` → save `Y` (e.g. `ZrSiTe*_FULL.mat`)
2. Optional: `scripts/real/create_run_environment.m` → `runs/<name>/`
3. Production: `scripts/real/MTSBD_block_realdata1.m` (via run-env launcher)
4. Standardized trunk (target): `scripts/real/run_real_data.m`
5. Paper viz: `examples/data/ZrSiTe/result/plotting_paper.m` (+ other real viz listed below)

**Official vs legacy (real):**


| Role                   | Script                                   | Status                                          |
| ---------------------- | ---------------------------------------- | ----------------------------------------------- |
| Production block run   | `scripts/real/MTSBD_block_realdata1.m`   | Official (wired in `runs/`)                     |
| Standardized trunk     | `scripts/real/run_real_data.m`           | Official target; keep both until feature parity |
| Interactive preprocess | `scripts/real/preprocess.m`              | Official                                        |
| Wrapper preprocess     | `lib/wrapper/preprocessRealData.m`       | Official (used by trunk)                        |
| Monolithic predecessor | `historical/real/MTSBD_block_realdata.m` | Retired                                         |
| Block-run clone        | `historical/real/run_test.m`             | Retired                                         |


**Run environments (optional, real-data only):** use when you need per-trial isolation, shared large inputs, or completion notifications. Not required for casual runs; do not use for synthetic. Minimum viable trial without full run-env: log file + output directory + pinned absolute config path.

### Synthetic single-dataset

1. `scripts/synthetic/run_synthetic_data.m`
2. Project tree via `createProjectStructure` / `saveDataset` / `saveRun` under `projects/`



### Synthetic parameter-space (dataset grid)

1. `scripts/phase_space/properGen_hierarchical.m` — SNR × density × side-length-ratio grid
2. `scripts/phase_space/run_parallel_dataset.m` — many **datasets**, one fixed solver combo
3. `scripts/phase_space/visualize_dataset_metrics.m` + `lib/phase_space/`

**Solver-param sweeps** (`lambda1` × `mini_loop`) live in the legacy runner
`historical/synthetic/run_parallel_tests.m` — not the primary phase-space path.

## Real-data visualization set


| Script                                          | Role                                    |
| ----------------------------------------------- | --------------------------------------- |
| `examples/data/ZrSiTe/result/plotting_paper.m`  | Publication figures                     |
| `lib/visualizeRealResult.m`                     | Per-slice reconstruction panels         |
| `lib/wrapper/visualizeRealRun.m`                | Post-run movies across slices           |
| `scripts/real/postprocessing.m`                 | Post-run kernel/QPI display             |
| `scripts/real/viz/directional_mask_waterfall.m` | Directional QPI mask diagnostic         |
| `utils/show_results.m`                          | Compact Y / reconstruction / A / X grid |
| `solvers/plot_activations.m`                    | Thresholded activation scatter          |




## Directory layout (target)

```
MT-SBD-STM/
  docs/REPO_STRUCTURE.md          # this file
  docs/REPO_STRUCTURE_DAG.md      # mermaid DAG
  history/repo_reorg.md           # migration table
  scripts/
    real/                         # preprocess, trunks, run-env, postprocess, viz/
    synthetic/                    # run_synthetic_data, block synthetic
    phase_space/                  # hierarchical gen, parallel run, metrics viz
  solvers/                        # MT_SBD, MTSBD_*, SBD_test_* APIs
  lib/                            # domain library (formerly Dong_func)
    wrapper/
    phase_space/
  core/  utils/  config/
  vendor/                         # slanCM, imshow3D, mat2im
  runs/                           # real run environments
  projects/                       # synthetic single-dataset projects
  artifacts/synthetic/            # batch datasets + parallel results
  historical/                     # retired scripts (real/, synthetic/, ...)
  examples/                       # thin demos + sample data
```



## Config policy

1. **Immutable templates** only: `config/Xsolve_config.mat`, `config/Asolve_config.mat`.
2. **Tunables** must use absolute paths under a run-env `config/`, worker dir, or session scratch — never bare `*_tunable.mat` writes to cwd.
3. `resolve_tunable_config` priority: run-env → `config/` (not `examples/`).
4. `update_config` rewrites relative tunable outputs to run-env `config/` or `config/runtime_tunables/` (never cwd).



## Path bootstrap

`init_sbd` adds: repo root, `core/`, `utils/`, `config/`, `lib/` (and subdirs), `solvers/`, `vendor/`, and `scripts/{real,synthetic,phase_space}/`.

## Related docs

- `[script_standardization.md](script_standardization.md)` — block IDs, checkpoints, logging
- `[FOLDER_STRUCTURE_ANALYSIS.md](FOLDER_STRUCTURE_ANALYSIS.md)` — nested project layout proposal
- `[../history/](../history/)` — topic-specific update/deprecation tables

