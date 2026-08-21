# Real-data reference-slice updates

| Date | Type | Component | Change | Caller Migration | Legacy Recovery |
| --- | --- | --- | --- | --- | --- |
| 2026-08-20 | Update | `reference-slice normalize` | Dropped the second interactive `normalizeBackgroundToZeroMean3D` on `Y_ref` after the volume is already normalized. `Y_ref` is taken from the normalized stack and only `proj2oblique` is reapplied. | `scripts/real/MTSBD_block_realdata1.m`, `lib/wrapper/decomposeRefSliceReal.m` | Restore the second `normalizeBackgroundToZeroMean3D(Y_ref, 'dynamic')` call from git history. |
| 2026-08-20 | Update | `eta from saved noise ROI` | Reuse the background rectangle from volume normalize for `eta` / `eta_data3d` instead of a second `estimate_noise` pick. `estimate_noise3D` now accepts an optional position. | `scripts/real/MTSBD_block_realdata1.m`, `lib/wrapper/decomposeRefSliceReal.m`, `lib/estimate_noise3D.m` | Call `estimate_noise3D(Y, 'std')` without a position, or restore `estimate_noise(Y_ref, 'std')` from git history. |
