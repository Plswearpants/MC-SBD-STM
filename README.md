# MC-SBD-STM: Multi-channel sparse blind deconvolution using the Riemannian Trust-Region Method (RTRM) on STM images
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Plswearpants/MT-SBD-STM)

This is a MATLAB package that aims to deconvolute multi-type kernels and their corresponding activations.

As sparse blind deconvolution is a nonconvex problem, using RTRM ensures that local minima will be found in the associated optimization objective.

This work is inspired by work in Single SBD-STM shown by [Cheung et al (2020)](https://www.nature.com/articles/s41467-020-14633-1), in which they formulated the Single SBD-STM problem:
<img width="646" alt="image" src="https://github.com/user-attachments/assets/63946883-6cfa-44b0-b877-e28cfaf07c72" />

We extend the algorithm into **multi-type defects** as we observe more than one type of defect in most systems. Here is an illustration of the work:
![image](https://github.com/user-attachments/assets/e48e51e4-87cc-4fa6-84c2-d0be148adbe3)

![image](https://github.com/user-attachments/assets/ddb843be-a8e6-4a6b-8871-60a3d1dd65ce)

Manopt is required. From the repo (or any subfolder), run `init_sbd` once per MATLAB session, or open a trunk / example script and run its path-init cell first.

## Run the 2D example

Script: [`examples/simple_MCSBD_example.m`](examples/simple_MCSBD_example.m).
Frozen observation (after you save it once): [`examples/example_data/simple_mcsbd_2d/simple_mcsbd_2d.mat`](examples/example_data/simple_mcsbd_2d/).

Use MATLAB **Run Section** on the `%%` cells. Solver knobs live in **DS01A**; generation knobs live in **GD01A**. Those two sets are independent: loading a dataset does not apply the run settings, and changing how the data is generated does not retune the solver for you.

| Goal | Route |
| --- | --- |
| Reproduce the bundled observation | **S0** → **LD01A** → **DS01A** → **VR01A** |
| Make a new observation and run it | **S0** → **GD01A** → **DS01A** → **VR01A** (skip **LD01A**, or the freeze will replace the new draw) |
| Freeze a dataset for later loads | **S0** → **GD01A** → **WS01A** (set `overwrite_example_dataset` if replacing an existing freeze) |

If the bundled `.mat` is missing, generate and freeze once, then use the load route after that. Generation also needs an LDoS `.mat` (`params.synGen.LDoS_path` in **GD01A**).

If you change **dataset** parameters (SNR, lattice size, defect density, LDoS, and so on), revisit **DS01A** as well (`lambda1`, `maxIT`, phase-II flags, kernel constraints). A recipe that worked on the frozen example can fail or look wrong on a noisier, denser, or larger observation.

Classic single-kernel SBD (no MCSBD trunk): [`examples/simple_SBD_example.m`](examples/simple_SBD_example.m).

## Real, synthetic, and phase-space runs

Official trunks live under [`scripts/`](scripts/). Previous scripts are `hist_*` files under [`historical/`](historical/) — keep those for recovery. Layout and conventions: [`docs/REPO_STRUCTURE.md`](docs/REPO_STRUCTURE.md).

| If you want to… | Start here | Then | Outputs land in |
| --- | --- | --- | --- |
| Clean a real STM stack (`.3ds` → `Y`) | [`scripts/real/real_preprocess.m`](scripts/real/real_preprocess.m) | Reuse that `Y` in the block run | `projects/real_<timestamp>/` |
| Decompose a real volume | [`scripts/real/real_block.m`](scripts/real/real_block.m) | Paper-style figures: [`examples/data/ZrSiTe/result/plotting_paper.m`](examples/data/ZrSiTe/result/plotting_paper.m) | same project folder as preprocess, if you point `params.project.existing_path` at it |
| Generate one synthetic dataset and run MCSBD (ref slice + all slices) | [`scripts/synthetic/synthetic_data.m`](scripts/synthetic/synthetic_data.m) | Follow the script’s GD / DS / DA / VR cells | `projects/synthetic_<timestamp>/` |
| Sweep a grid of synthetic datasets, then plot metrics | [`scripts/phase_space/properGen_hierarchical.m`](scripts/phase_space/properGen_hierarchical.m) | [`run_parallel_dataset.m`](scripts/phase_space/run_parallel_dataset.m) → [`visualize_dataset_metrics.m`](scripts/phase_space/visualize_dataset_metrics.m) | `artifacts/synthetic/` |

| Piece | Where |
| --- | --- |
| Live solvers | [`solvers/`](solvers/) (`MC_SBD`, `MCSBD_synthetic`, `MCSBD_all_slice_modified`, `SBD_test_multi_parallel`, `SBD`) |
| Domain helpers / wrappers | [`lib/`](lib/) |
| Immutable solver templates | [`config/`](config/) (`Xsolve_config.mat`, `Asolve_config.mat`) |
| Parked experiments | [`historical/`](historical/) (`hist_` prefix) |
