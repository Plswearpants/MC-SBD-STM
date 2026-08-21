# Domain library (`lib/`)

Formerly `Dong_func/`. Domain helpers for STM I/O, synthetic generation, metrics, visualization, and workflow wrappers.

| Subfolder | Role |
|-----------|------|
| `wrapper/` | Trunk orchestration façades (real + synthetic) |
| `phase_space/` | Parameter-space metrics and heatmaps |
| `basic/` | Logging helpers (`logUsedBlocks`, `setLogFile`) |
| `data_preprocessing/` | Legacy streak/defect helpers |
| `colormap/` | Saved colormap `.mat` assets |

Stack movies: `writePixelVideo` writes a native-resolution (pixel-to-pixel) video along dim 3 with energy labels.

Solver configs: use `utils/update_config.m` only (duplicate removed).
Bootstrapping: `init_sbd` addpaths this tree.
