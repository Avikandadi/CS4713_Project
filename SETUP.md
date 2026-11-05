# Setup

Reproduces *Robust Decision Trees Against Adversarial Examples* (Chen et al., ICML 2019) on
MNIST 2 vs. 6 with the authors' code ([chenhongge/RobustTrees](https://github.com/chenhongge/RobustTrees),
a fork of XGBoost 0.72), run in Docker.

| file | what it does |
|---|---|
| `Dockerfile` | builds the authors' `xgboost` CLI and a Python env (xgboost 1.7.6, gurobipy) |
| `run.sh` | runs a command in the container (mounts `RobustTrees/`, `scripts/`, `results/`, the license) |
| `scripts/make_mnist26.py` | rebuilds the MNIST 2-vs-6 dataset |
| `scripts/experiment.sh <eps> <seed>` | trains one model, attacks it, adds a row to `results/results.csv` |

## Run it

```bash
cd "<path to>/CS4713_Project"      # quote it: the path has spaces
git clone --recursive https://github.com/chenhongge/RobustTrees.git   # gitignored
docker build -t robust-trees .
./run.sh python scripts/make_mnist26.py          # expect 11876 train / 1990 test rows

# smoke test (works with the free Gurobi license)
./run.sh env NTREES=10 NPOINTS=10 bash scripts/experiment.sh 0   0   # natural
./run.sh env NTREES=10 NPOINTS=10 bash scripts/experiment.sh 0.3 0   # robust

# real runs; defaults NTREES=200 NPOINTS=50 ETA=0.3
./run.sh bash scripts/experiment.sh 0.3 1                     # train + attack (needs full license)
./run.sh env NO_ATTACK=1 bash scripts/experiment.sh 0.3 1     # train only (no license needed)
./run.sh env ATTACK_ONLY=1 bash scripts/experiment.sh 0.3 1   # attack a model trained earlier
```

`results/results.csv` keeps one row per (eps, seed, trees). A train-only run leaves the
distortion columns blank, and a later `ATTACK_ONLY=1` run fills them in.

`eps=0` means natural training (`tree_method=exact`). Any other value means robust training
(`tree_method=robust_exact robust_eps=<eps>`). Every run uses `data/binary_mnist.conf`
(depth 6) with `subsample=0.8 colsample_bytree=0.8 seed=<seed>`, so only ε and the seed
change between runs. Logs go to `results/runs/eps<eps>_seed<seed>/`.

Smoke-test result (10 trees, 10 points, 2026-11-05):

| eps | test acc | avg ℓ∞ distortion |
|---|---|---|
| 0 (natural) | 0.9925 | 0.076 |
| 0.3 (robust) | 0.9894 | 0.299 |

Same accuracy, about 4× harder to fool. Paper (1000 trees): .998 / .064 natural, .997 / .315 robust.

## Gurobi license (needed for models with more than about 10 trees)

The attack solves an exact MILP with Gurobi. The free license bundled with `pip install gurobipy`
only handles tiny models. Get a free **Academic WLS** license (it works inside Docker,
unlike the regular academic license, which is tied to one machine):

1. Sign up at gurobi.com with your university email (campus network or VPN may be needed).
2. *Licenses → Request → WLS Academic*.
3. At license.gurobi.com: *API Keys → Create → Download* `gurobi.lic`.
4. Save it as `gurobi/gurobi.lic` in this repo. It's gitignored, so don't share it.
   `run.sh` mounts it automatically.

## Gotchas

- **Apple Silicon build:** the Dockerfile adds `USE_SSE=0 ADD_CFLAGS=-fsigned-char`. Without
  `-fsigned-char`, `xgboost` loops forever reading the `.conf` file and runs out of memory
  (on ARM `char` is unsigned, and `src/common/config.h` compares a `char` to `EOF`).
- **Python xgboost must be 1.7.6:** newer versions can't load the fork's model files.
- **Dataset needs explicit zeros:** every pixel is written, even zeros. Missing zeros are
  treated as missing values and break robust training.
- **Feature indices:** features are 1-indexed (`f1..f784`). In your own Python code, load with
  `load_svmlight_file(path, n_features=785, zero_based=True)`, or every feature shifts by one.
- **`Unable to open Gurobi license file`:** not an issue with `experiment.sh` (it falls back
  to the free license), only in your own commands without `gurobi/gurobi.lic`.
- **Docker not running:** `open -a Docker`.
