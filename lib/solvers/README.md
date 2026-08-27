# Solvers

Live entrypoints (`init_sbd` puts this folder on the path):

| Function | Used by |
| --- | --- |
| `MC_SBD` | real reference-slice (`real_block`) |
| `MCSBD_all_slice_modified` | real all-slice |
| `MCSBD_synthetic` | synthetic reference-slice |
| `MCSBD_synthetic_all_slice` | synthetic all-slice (`synthetic_data` DA01A) |
| `SBD_test_multi_parallel` | phase-space worker |
| `SBD` | classic single-kernel SBD |

Experimental copies: `historical/solvers/hist_*`.
