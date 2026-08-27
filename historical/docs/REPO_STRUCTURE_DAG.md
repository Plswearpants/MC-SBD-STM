# Repository Structure DAG

Living DAG of functional streams and shared core.
Keep in sync with [`REPO_STRUCTURE.md`](REPO_STRUCTURE.md) and
[`../historical/history/repo_reorg.md`](../historical/history/repo_reorg.md).

## Functional streams

```mermaid
flowchart TB
  subgraph real [RealDataStream]
    Rpre[scripts/real/real_preprocess]
    Rrun[scripts/real/real_block]
    Rfull[historical/real/hist_run_real_data combined]
    Rviz[plotting_paper / visualizeRealResult]
    Rproj["project folder + *_LOGfile.txt"]
    Rstore["store/real/processed/<Material>_<MMDD>"]
    Rpre --> Rrun --> Rviz
    Rfull --> Rviz
    Rpre --> Rproj
    Rrun --> Rproj
    Rpre --> Rstore
    Rstore --> Rrun
    Rfull --> Rproj
  end

  subgraph synOne [SyntheticSingleDataset]
    Srun[scripts/synthetic/synthetic_data]
    Sex[examples/simple_MCSBD_example]
    Sviz[VR01A visualizeResults]
    Sproj[run entrance/projects via createProjectStructure]
    Sdata[examples/example_data/simple_mcsbd_2d]
    Sldos[store/synthetic/ldos]
    Srun --> Sviz
    Sproj --> Srun
    Sldos --> Srun
    Sdata --> Sex
    Sex --> Sviz
  end

  subgraph synBatch [SyntheticParameterSpace]
    Bgen[scripts/phase_space/properGen_hierarchical]
    Brun["scripts/phase_space/run_parallel_dataset\n(parfor -> SBD_test_multi_parallel)"]
    Bviz[visualize_dataset_metrics + lib/phase_space]
    Bdata[store/phase_space]
    Bgen --> Brun --> Bviz
    Bdata --> Brun
    Bdata --> Bviz
  end

  subgraph shared [SharedCore]
    Core[core/]
    Lib[lib/ domain]
    Wrap[lib/wrapper]
    Utils[utils/config]
    Algo[solvers/ MC_SBD MCSBD_synthetic MCSBD_all_slice_modified SBD SBD_test_multi_parallel]
    Vendor[vendor/]
  end

  Rrun --> Algo
  Rfull --> Algo
  Srun --> Algo
  Brun --> Algo
  Wrap --> Lib
  Algo --> Core
  Algo --> Utils
```

## Iteration status

| Iteration | Focus | Status |
|-----------|-------|--------|
| 0 | Inventory docs | Done |
| 1 | Soft retirement + config/path hygiene | Done |
| 2 | scripts regroup | Done |
| 3 | Artifact roots + real viz set | Done |
| 4 | solvers / vendor / lib rename | Done |
| 5 | Close docs/disk drift; `hist_` previous scripts; `RUN_` official trunks; two-way real path | Done |
| 6 | Drop run-env; trial record is project folder + `*_LOGfile.txt` | Done |
| 7 | Remove root stubs; park `hist_*` under `historical/`; drop `RUN_` prefix | Done |
| 8 | Phase-space viz: independent B/V Run Section cells; drop master `run_build`/`run_visualize` | Done |
| 9 | Simple MCSBD example: freeze/load data+params, no session log | Done |
| 10 | Trim `solvers/`: delete dead/broken; `hist_` experimental solvers | Done |
| 11 | Payload roots: `store/` + `paper/` + `projects/`; drop `artifacts/` | Done |
| 12 | Docs cleanup: park session memos in `historical/docs/`; logs only in `historical/history/` | Done |
