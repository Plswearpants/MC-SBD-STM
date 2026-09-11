# MC-SBD-STM: Multi-channel sparse blind deconvolution using the Riemannian Trust-Region Method (RTRM) on STM images
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Plswearpants/MC-SBD-STM)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22135528.svg)](https://doi.org/10.5281/zenodo.22135528)

## Overview
A MATLAB package that performs multi-channel deconvolution end-to-end, primarily on STM measurements (grid spectroscopy and topography), to recover individual defect kernels and their corresponding sparse activations. This is primarily applied to study the scattering signatures around different species of defects and to recover defect-resolved quasiparticle interference(QPI) patterns. 

This package enables pre-processing of experimental grid spectroscopy, running the MC-SBD algorithm on standard processed grids, and visualizing the output defect-resolved QPIs. It also equips a synthetic data generation-processing-visualization pipeline to validate this algorithm against generated ground truth.

As sparse blind deconvolution is a nonconvex problem, using RTRM ensures that local minima will be found in the associated optimization objective. Inspired by [this work](https://www.nature.com/articles/s41467-020-14633-1), this algorithm acts on observations with **multi-type defects**, as we observe more than one defect species in most systems, thus making this algorithm the first practical deconvolution algorithm in STM-QPI processing. 

A full list of detailed information on the algorithm and its physical background can be found in this thesis: [Defect-resolved scattering in quantum materials: a scanning tunneling microscope study with algorithmic multi-channel deconvolution](https://open.library.ubc.ca/soa/cIRcle/collections/ubctheses/24/items/1.0451233)

## Requirement and installation

Version: MATLAB R2019b or later

Required toolbox: 
- **Manopt(Tool­boxes for opti­mization on manifolds and linear spaces)**: used by the core MC-SBD algorithm. See [this](https://www.manopt.org) for details on installation.
- **Image Processing Toolbox**: MATLAB toolbox

Recommended, necessary for running those trunks:
- **Signal Processing Toolbox** — required in the real data pipeline, by [`run_preprocess.m`](run%20entrance/scripts/real/real_preprocess.m) Nanonis load (`load3dsall` → `gaussfilter1d`); Gaussian/Kaiser kernel windows
- **Parallel Computing Toolbox** — required in the phase-space pipeline, by [`run_parallel_dataset.m`](run%20entrance/scripts/phase_space/run_parallel_dataset.m) (`parpool` / `parfor`)
- **Optimization Toolbox** — required in the real data pipeline, Lorentzian Bragg-peak fit in `lorentzianBraggRemove`

After installing the required packages, you can clone this repo via
```
git clone https://github.com/Plswearpants/MC-SBD-STM.git
```
Note that all the toolboxes should be on the MATLAB path, especially for Manopt. Then you can run the demo mentioned below. 

## A 2D illustration of this work:
To clearly communicate the concepts and results involved, we follow the notation: 

$$Y = \sum_i(A_i * X_i)$$,

where $Y$ is the 3D (or 2D) observation, $A_i$ is the i-th channel 3D (or 2D) kernel, and $X_i$ is the i-th channel 2D activation map. In the case of STM-QPI, $A_i$ and $X_i$ are the defect-resolved QPI pattern and defect location map of species $i$, respectively. However, the core of the algorithm can be used for any case following the same data structure. 

**Script**: [`examples/simple_MCSBD_example.m`](examples/simple_MCSBD_example.m).
**Demo observation Y**: A 2-kernel demo observation is stored[`examples/example_data/simple_mcsbd_2d/simple_mcsbd_2d.mat`](examples/example_data/simple_mcsbd_2d/). 

### Results:  
**Original observation vs reconstructed observation:**
<img width="2041" height="880" alt="image" src="https://github.com/user-attachments/assets/2315a0b5-dbd1-45ca-8ea4-6f6c7a0438a9" />

**Activation comparison**: K1, K2 are two distinct kernels. $X_0$ and $X_{out}$ are the ground truth and output activation map, respectively. The diff is to show qualitatively that there is no offset in the matching.  
<img width="1530" height="1044" alt="image" src="https://github.com/user-attachments/assets/d816d87e-bfdf-43bb-a7d7-196463b3dffb" />

**Kernel comparison**: 
<img width="2027" height="1047" alt="image" src="https://github.com/user-attachments/assets/ac86ee64-62af-4d1d-b37c-ed9286e08387" />
The reason the output kernel looks cleaner than the ground truth is that the algorithm works based on a statistical average, and the output kernel will have higher SNR than that of the ground truth kernel, scaled with the number of occurrences of the corresponding defect. 

**Convergence**: This simple run converges within 15 iterations and finishes within 10 mins. 
<img width="1087" height="456" alt="image" src="https://github.com/user-attachments/assets/ae7f9278-b36d-457e-be06-d83ed96fee06" />

## Run the demo
The demo should take minutes to run. 
Script: [`examples/simple_MCSBD_example.m`](examples/simple_MCSBD_example.m).
Frozen observation: [`examples/example_data/simple_mcsbd_2d/simple_mcsbd_2d.mat`](examples/example_data/simple_mcsbd_2d/).

Use MATLAB **Run Section** on the `%%` cells. Solver knobs live in **DS01A**; generation knobs live in **GD01A**. Those two sets are independent: you can modify the dataset to run and the solver parameters in a modular way. 

| Goal | Route |
| --- | --- |
| Reproduce the bundled observation | **S0** → **LD01A** → **DS01A** → **VR01A** |
| Make a new observation and run it | **S0** → **GD01A** → **DS01A** → **VR01A** (skip **LD01A**, or the freeze will replace the new draw) |
| Freeze a dataset for later loads | **S0** → **GD01A** → **WS01A** (set `overwrite_example_dataset` if replacing an existing freeze) |

If you wish to test on another observation than the provided Y, you can generate a new observation and freeze once, then use the load route after that. Generation also needs an LDoS `.mat` (`params.synGen.LDoS_path` in **GD01A**).

If you change **dataset** parameters (SNR, lattice size, defect density, LDoS, and so on), revisit **DS01A** as well (`lambda1`, `maxIT`, phase-II flags, kernel constraints). A recipe that worked on the frozen example can fail or look wrong on a noisier, denser, or larger observation. 

## Instructions for use: Real, synthetic, and phase-space runs

Official trunks live under [`run entrance/scripts/`](run%20entrance/scripts/). Previous scripts are `hist_*` files under [`historical/`](historical/).

Note that this package only supports a preprocessing pipeline for raw grid maps in the .3ds format. For other formats, users need to load their raw data into a MATLAB array, replacing the original loading block LR01A. The rest of the operation should stay the same.  

| Task | Start here | Next steps | Outputs land in |
| --- | --- | --- | --- |
| Clean a real STM stack (`.3ds` → `Y`) | [`run entrance/scripts/real/real_preprocess.m`](run%20entrance/scripts/real/real_preprocess.m) | Reuse that `Y` in the block run | `run entrance/projects/real_<timestamp>/` |
| Decompose a real volume | [`run entrance/scripts/real/real_block.m`](run%20entrance/scripts/real/real_block.m) | Paper-style figures: [`paper/figures/Main Figures/plotting_paper.m`](paper/figures/Main%20Figures/plotting_paper.m) | same project folder as preprocess, if you point `params.project.existing_path` at it |
| Generate one synthetic dataset and run MCSBD (ref slice + all slices) | [`run entrance/scripts/synthetic/synthetic_data.m`](run%20entrance/scripts/synthetic/synthetic_data.m) | Follow the script’s GD / DS / DA / VR cells | `run entrance/projects/synthetic_<timestamp>/` |
| Sweep a grid of synthetic datasets, then plot metrics | [`run entrance/scripts/phase_space/properGen_hierarchical.m`](run%20entrance/scripts/phase_space/properGen_hierarchical.m) | [`run_parallel_dataset.m`](run%20entrance/scripts/phase_space/run_parallel_dataset.m) → [`visualize_dataset_metrics.m`](run%20entrance/scripts/phase_space/visualize_dataset_metrics.m) | `store/phase_space/` |

| Piece | Where |
| --- | --- |
| Live solvers | [`lib/solvers/`](lib/solvers/) (`MC_SBD`, `MCSBD_synthetic`, `MCSBD_all_slice_modified`, `SBD_test_multi_parallel`) |
| Domain helpers / wrappers | [`lib/`](lib/) |
| Solver templates (local only) | [`config/`](config/) `.mat` files — regenerated by `init_sbd` / `default_config_settings`; not on GitHub |
| Parked recovery scripts | [`historical/`](historical/) (`hist_` prefix); reorg notes under `historical/docs/` and `historical/history/archive/` stay local |
