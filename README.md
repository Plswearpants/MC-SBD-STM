# MC-SBD-STM: Multi-channel sparse blind deconvolution using the Riemannian Trust-Region Method (RTRM) on STM images
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Plswearpants/MT-SBD-STM)

This is a MATLAB package that performs multi-channel deconvolution, primarily on STM measurements (grid spectroscopy and topography), to recover individual defect kernels and their corresponding sparse activations. This is useful especially in studying the scattering signatures around different species of defects, also known as quasi-particle interference patterns. As sparse blind deconvolution is a nonconvex problem, using RTRM ensures that local minima will be found in the associated optimization objective. This work is inspired by work in Single SBD-STM shown by [Cheung et al (2020)](https://www.nature.com/articles/s41467-020-14633-1), in which they formulated the Single SBD-STM problem. Our algorithm acts on observations with **multi-type defects**, as we observe more than one defect species in most systems, thus making this algorithm the first practical deconvolution algorithm in STM-QPI processing. 

We follow the notation: 
$Y = \sum_i(A_i * X_i)$,
where $Y$ is the 3D (or 2D) observation, $A_i$ is the i-th channel 3D (or 2D) kernel, and $X_i$ is the i-th channel 2D activation map. In the case of STM-QPI, $A_i$ and $X_i$ are the defect-resolved QPI pattern and defect location map of species i, respectively. However, the core of the algorithm can be used for any case following the same data structure. 

A full list of detailed information on the algorithm and its physical background can be found in this thesis: [Defect-resolved scattering in quantum materials: a scanning tunneling microscope study with algorithmic multi-channel deconvolution](https://open.library.ubc.ca/soa/cIRcle/collections/ubctheses/24/items/1.0451233)

## A 2D illustration of the work:
**Script**: [`examples/simple_MCSBD_example.m`](examples/simple_MCSBD_example.m).
**Demo observation Y**: A 2-kernel demo observation is stored[`examples/example_data/simple_mcsbd_2d/simple_mcsbd_2d.mat`](examples/example_data/simple_mcsbd_2d/). 
### Results:  
**Original observation vs reconstructed observation:**
<img width="2041" height="880" alt="image" src="https://github.com/user-attachments/assets/2315a0b5-dbd1-45ca-8ea4-6f6c7a0438a9" />

**Activation comparison**: K1, K2 are two distinct kernels. $X_0$ and $X_{out}$ are the ground truth and output activation map, respectively. 
<img width="1530" height="1044" alt="image" src="https://github.com/user-attachments/assets/d816d87e-bfdf-43bb-a7d7-196463b3dffb" />

**Kernel comparison**: 
<img width="2027" height="1047" alt="image" src="https://github.com/user-attachments/assets/ac86ee64-62af-4d1d-b37c-ed9286e08387" />
The reason the output kernel looks cleaner than the ground truth is that the algorithm works based on a statistical average, and the output kernel will have higher SNR than that of the ground truth kernel, scaled with the number of occurrences of the corresponding defect. 

**Convergence**: This simple run converges within 15 iterations and finishes within 10 mins. 
<img width="1087" height="456" alt="image" src="https://github.com/user-attachments/assets/ae7f9278-b36d-457e-be06-d83ed96fee06" />

## Run the 2D example

Script: [`examples/simple_MCSBD_example.m`](examples/simple_MCSBD_example.m).
Frozen observation: [`examples/example_data/simple_mcsbd_2d/simple_mcsbd_2d.mat`](examples/example_data/simple_mcsbd_2d/).

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
