## Update and Deprecation Log

| Date | Type | Component | Change | Caller Migration | Legacy Recovery |
| --- | --- | --- | --- | --- | --- |
| 2026-05-13 | Update | `measurement SNR pipeline` | Added optional output-kernel SNR evaluation that reuses raw-data sigma_noise and includes drawn-vs-output SNR comparison plots. | Updated `scripts/measure_snr_from_measurement.m`; added helper `Dong_func/estimateKernelSNRWithFixedNoise.m`. | Recover prior script behavior from git history for `scripts/measure_snr_from_measurement.m`. |
| 2026-05-13 | Update | `measure_snr_from_measurement` readability refactor | Reorganized script into clear stages (baseline drawn-kernel evaluation, optional recovered-kernel comparison, explicit comparison-method rationale) and grouped helper utilities for maintainability. | Refactored `scripts/measure_snr_from_measurement.m` flow and helper structure without changing the quantitative goals. | Recover pre-refactor script layout from git history for `scripts/measure_snr_from_measurement.m`. |
