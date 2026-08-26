## Update and Deprecation Log

| Date | Type | Component | Change | Caller Migration | Legacy Recovery |
| --- | --- | --- | --- | --- | --- |
| 2026-03-26 | Deprecation | `MCSBD_all_slice.m` | Retired direct implementation; now a warning wrapper that forwards to `MCSBD_all_slice_modified.m` | Updated direct call sites in `scripts/run_test.m`, `scripts/MCSBD_block_realdata.m`, `scripts/MCSBD_block_realdata1.m`, `Dong_func/wrapper/runAllSlicesReal.m`, `examples/data/Ag111/Ag111_run.m` | Recover pre-retirement body from git history for `MCSBD_all_slice.m` |
| 2026-08-25 | Retirement | `MCSBD_all_slice.m` shim | Deleted the forwarding wrapper. Live all-slice path is `MCSBD_all_slice_modified` only. | No remaining `MCSBD_all_slice(` call sites. | Restore `solvers/MCSBD_all_slice.m` from git history if a compatibility alias is needed. |

### Append Rule

Add one row per update/deprecation. Keep entries chronological and include concrete file paths in the migration column.
