# Store — reusable library

Named payloads that survive a sitting. Session scratch: `run entrance/projects/`. Manuscript freeze: [`paper/`](../paper/).

Binaries (`.mat`, `.3ds`) are gitignored. This file is the tracked map.

Promote keepers here; do not work out of `store/` during a sitting.

```
store/
  real/
    raw/<sample>/                      # immutable .3ds
    processed/<Material>_<MMDD>/       # Y / *_FULL.mat
    runs/<Material>_<MMDD>/            # tagged ALL.mat that used that Y
  synthetic/
    datasets/  runs/  ldos/
  phase_space/
    datasets/  parallel_runs/  metrics/
```

Real index is **material + date** (`ZrSiTe_0528`, `LiFeAs_0721`, `PtSn4_0906`, …). Trunks compose that folder from `cfg.io.sample` + `cfg.io.sample_date`.
