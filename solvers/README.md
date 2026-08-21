# Solvers

Algorithm entrypoints moved from the repo root:

- `MT_SBD.m` — multi-type SBD for real data
- `MTSBD_all_slice_modified.m` — active all-slice implementation (`MTSBD_all_slice.m` is a thin retirement shim)
- `MTSBD_synthetic*.m` — synthetic drivers
- `SBD*.m` / `SBD_test_multi_parallel.m` — classic / parallel SBD variants
- `plot_activations.m`, `streak_correction.m` — shared solver-adjacent utilities

Added to path by `init_sbd`. See [`../docs/REPO_STRUCTURE.md`](../docs/REPO_STRUCTURE.md).
