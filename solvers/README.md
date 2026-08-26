# Solvers

Live algorithm entrypoints (on path via `init_sbd`):

- `MC_SBD.m` — multi-channel SBD for real reference-slice runs
- `MCSBD_all_slice_modified.m` — real all-slice driver (`real_block` / `runAllSlicesReal`)
- `MCSBD_synthetic.m` — synthetic reference-slice driver (`decomposeReferenceSlice`)
- `MCSBD_synthetic_all_slice.m` — synthetic all-slice driver (`synthetic_data` DA01A)
- `SBD_test_multi_parallel.m` — phase-space worker (`run_parallel_dataset`)
- `SBD.m` — classic single-kernel SBD (`examples/simple_SBD_example.m`)

Historical / experimental solvers live under `historical/solvers/` with a `hist_` prefix (`hist_SBD_test`, `hist_streak_correction`, `hist_MCSBD_synthetic_Xregulated*`). `init_sbd` addpaths that folder too. See [`../docs/REPO_STRUCTURE.md`](../docs/REPO_STRUCTURE.md).
