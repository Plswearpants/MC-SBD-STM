## Update and Deprecation Log

| Date | Type | Component | Change | Caller Migration | Legacy Recovery |
| --- | --- | --- | --- | --- | --- |
| 2026-05-13 | Deprecation | `measurement cutoff workflow` | Retired session-added cutoff estimation and cutoff visualization from measurement tooling. | Removed cutoff calls/outputs/plots in `scripts/measure_snr_from_measurement.m`; deleted `Dong_func/estimateKernelCutoffFromMeasurement.m`. | Recover retired behavior from git history for `scripts/measure_snr_from_measurement.m` and `Dong_func/estimateKernelCutoffFromMeasurement.m`. |
