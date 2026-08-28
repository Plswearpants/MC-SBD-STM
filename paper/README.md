# Paper freeze and figures

Snapshot of what the manuscript used. Freeze `.mat` files stay on disk (gitignored; too large for GitHub) and are Windows hard links into `store/` (same bytes, two names). Do not overwrite them for a new experiment — add a new freeze name if the paper set changes. Movies and `plotting_paper.m` are tracked.

```
paper/
  freeze/real/            # Y/FULL + *_ALL.mat
  freeze/phase_space/     # snr=3,5,7.mat
  figures/                # png/pdf + movies; plotting_paper.m
```

Assembler: `paper/figures/Main Figures/plotting_paper.m`. Working copies: [`store/`](../store/). How to run the rest of the repo: root [`README.md`](../README.md).
