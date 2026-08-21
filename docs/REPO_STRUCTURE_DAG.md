# Repository Structure DAG

Living DAG of functional streams and shared core.
Keep in sync with [`REPO_STRUCTURE.md`](REPO_STRUCTURE.md) and
[`../history/repo_reorg.md`](../history/repo_reorg.md).

## Functional streams

```mermaid
flowchart TB
  subgraph real [RealDataStream]
    Rpre[scripts/real/preprocess]
    Rrun[MTSBD_block_realdata1 / run_real_data]
    Rviz[plotting_paper / visualizeRealResult]
    Renv[runs/ optional create_run_environment]
    Rpre --> Rrun --> Rviz
    Renv --> Rrun
  end

  subgraph synOne [SyntheticSingleDataset]
    Sgen[lib/wrapper/generateSyntheticData]
    Srun[scripts/synthetic/run_synthetic_data]
    Sviz[visualizeResults]
    Sproj[projects/ via createProjectStructure]
    Sgen --> Srun --> Sviz
    Sproj --> Srun
  end

  subgraph synBatch [SyntheticParameterSpace]
    Bgen[scripts/phase_space/properGen_hierarchical]
    Brun[scripts/phase_space/run_parallel_dataset]
    Bviz[visualize_dataset_metrics + lib/phase_space]
    Bdata[artifacts/synthetic]
    Bgen --> Brun --> Bviz
    Bdata --> Brun
    Bdata --> Bviz
  end

  subgraph shared [SharedCore]
    Core[core/]
    Lib[lib/ domain]
    Wrap[lib/wrapper]
    Utils[utils/config]
    Algo[solvers/ MT_SBD MTSBD SBD_test]
    Vendor[vendor/]
  end

  Rrun --> Algo
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
