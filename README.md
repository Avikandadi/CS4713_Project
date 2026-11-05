# Does Robust Training Protect Trees from Poisoning?

CS 4713/5713 Computational Learning Theory, Fall 2026: Track C (attacker vs. defender), implementation project
**Team:** Avinash Kandadi, Thomas Petersen
**Status as of the midterm checkpoint (2026-11-05).** Proposal: [`documents/Project_Proposal.pdf`](documents/Project_Proposal.pdf). How to run everything: [`SETUP.md`](SETUP.md).

## The question

Chen et al. (ICML 2019, [`documents/Robust_DT.pdf`](documents/Robust_DT.pdf)) train decision trees that resist
small **test-time** changes to their inputs. Shafahi et al., *Poison Frogs!* (NeurIPS 2018,
[`documents/Posion_attack.pdf`](documents/Posion_attack.pdf)) show that a few correctly labeled
**training-time** poisons can flip one chosen test prediction. We ask whether a tree that resists the first
attack is also harder to poison.

- **Setup:** XGBoost trees on MNIST 2 vs. 6, robust-training strength ε ∈ {0, 0.1, 0.2, 0.3}
  (ε = 0 is a normal tree).
- **Poisoning:** k ∈ {1, 5, 10, 25, 50} poisons per target, 50 random targets. Trees have no learned
  feature space, so each poison is a base-class image blended with the target at opacity γ = 0.2 and
  labeled as the base class.
- **Measured:** fraction of targets flipped, test accuracy, and the ℓ∞ change needed to fool each model.
- **Hypothesis:** robust training helps against test-time attacks but not against poisoning.

## Checkpoint status

| proposal milestone | status |
|---|---|
| **By Oct 22:** set up the authors' RobustTrees code, train normal and robust trees on MNIST 2 vs. 6, confirm robust trees are harder to fool | ✅ done |
| **By Nov 5:** experiment set 1, comparing normal vs. robust trees across ε with several seeds (accuracy and distortion) | ⏳ pipeline ready; full runs blocked on the Gurobi license |
| **By Nov 5:** one poisoning sanity check | ❌ not started |
| **By Nov 5:** midterm figure and table | ⏳ smoke-test table below; figure waits on experiment set 1 |

## What has been done

### 1. Environment: the authors' code running in Docker
- Cloned [chenhongge/RobustTrees](https://github.com/chenhongge/RobustTrees), a fork of XGBoost 0.72
  that adds robust training (`tree_method=robust_exact`). Their C++ source is unmodified.
- `Dockerfile` (Ubuntu 24.04, GCC 13) builds the fork's `xgboost` command-line tool and a Python
  env (`xgboost==1.7.6`, `gurobipy`) for the attack. `run.sh` runs any command inside the container.

### 2. Dataset: MNIST 2 vs. 6
- The authors' download links are dead, so `scripts/make_mnist26.py` rebuilds the dataset from the
  original MNIST files: digit 2 → label 0, digit 6 → label 1, pixels scaled to [0, 1], all 784
  pixels written explicitly.
- Row counts match the paper exactly: **11,876 train** (5,958 / 5,918) and **1,990 test** (1,032 / 958).

### 3. Reproduction check: robust trees are harder to fool
Models were attacked with the authors' Kantchelian attack: a MILP solved with Gurobi that finds the
**exact** smallest ℓ∞ change that flips the prediction.

| model (10 trees, depth 6, seed 0) | test accuracy | avg ℓ∞ distortion (10 test points) |
|---|---|---|
| natural (ε = 0) | 0.9925 | 0.076 |
| robust (ε = 0.3) | 0.9894 | 0.299 |
| *paper, natural (1000 trees)* | *0.998* | *0.064* |
| *paper, robust (1000 trees)* | *0.997* | *0.315* |

**Robust trees need about 4× more perturbation to fool, at nearly the same accuracy**, and the robust
model's distortion sits right around ε = 0.3, as the paper predicts. Two more checks:
- **20 trees** (the paper's two configs): natural reached 0.9945 accuracy and 0.067 distortion, close to
  the paper's 0.064. Robust reached 0.9950 accuracy, but its attack needs the full license.
- **Control:** a depth-6 tree trained with the normal method (`exact`) gives 0.085, so the gain comes
  from the robust split rule, not from deeper trees.

### 4. Experiment pipeline (ready for experiment set 1)
- `scripts/experiment.sh <eps> <seed>` trains one model, attacks it, and adds a row to
  `results/results.csv`.
- Every run uses the same depth-6 config with `subsample=0.8 colsample_bytree=0.8`. Exact training is
  otherwise deterministic, so this is what makes seeds matter.
- Defaults are 200 trees and 50 attacked points. The paper used 1000 trees, but the exact attack gets
  slow on large models.
- Training and attacking can run separately (`NO_ATTACK=1`, `ATTACK_ONLY=1`), so all models can be
  trained now and attacked once the license is available.

## Difficulties

| problem | what happened | resolution |
|---|---|---|
| Build on Apple Silicon | The fork's Makefile adds an x86-only flag (`-msse2`). Worse, the built program ran out of memory before training even started: on ARM, `char` is unsigned, so the config-file reader never detects end of file and loops forever. | Build flags `USE_SSE=0 ADD_CFLAGS=-fsigned-char`, no source edits |
| Old model format | XGBoost 2.x+ can't load the fork's v0.72 model files | Pinned `xgboost==1.7.6` for the Python side |
| Dead data links | The authors' Dropbox links no longer work | Rebuilt the dataset from raw MNIST; counts match the paper |
| Missing values | Sparse LIBSVM files drop zero pixels, which the fork treats as *missing* and which breaks robust training | Write every pixel explicitly |
| Feature indexing | Features are 1-indexed; loading with default settings shifts every feature by one and silently lowers accuracy (0.9905 vs. 0.995) | Load with `n_features=785, zero_based=True` |
| **Gurobi license (open)** | The free license only handles models of about 10 trees. The academic WLS license needs academic verification (campus network or VPN). | Pending; train now, attack later |

## Plan for the rest of the semester

**Finish the midterm items (now):**
1. Choose the learning rate for 200 trees. `ETA=0.3` came from the smoke test; the paper used
   0.01–0.02 with 1000 trees. Check accuracy with a few train-only runs.
2. Train experiment set 1: ε ∈ {0, 0.1, 0.2, 0.3} × 3 seeds = 12 models, no license needed
   (`NO_ATTACK=1`).
3. Get the Gurobi WLS license, time one 200-tree attack, then attack all 12 models (`ATTACK_ONLY=1`).
4. Make the figure (accuracy and ℓ∞ distortion vs. ε, error bars over seeds) and the table vs. the paper's Table 3.
5. Poisoning sanity check: one ε = 0 and one ε = 0.3 model, a few targets, k = 50 blended poisons
   (γ = 0.2). Does any target flip?

**Nov 6–Nov 25: experiment set 2, the poisoning study**
- Add a poisoning step: pick a target test image, blend base-class training images with it at γ = 0.2,
  label them as the base class, add them to the training set, retrain, and check whether the target flips.
- Sweep ε ∈ {0, 0.1, 0.2, 0.3} × k ∈ {1, 5, 10, 25, 50} over 50 random targets and several seeds,
  recording the fraction flipped and clean test accuracy.
- Compare poisons built from one base image vs. many different base images.
- Cost to plan for: each (ε, k, target) needs a retrained model. Robust training takes about
  0.1 s/tree on 12 threads, so a 200-tree robust model takes about 20–30 s.

**Nov 26–Dec 14: analysis and write-up**
- Analysis, talks on Dec 8 / Dec 10, final report (5–6 pages) and code due Dec 14.

## Repository layout

```
README.md               this file: project status
SETUP.md                how to build, run, and get the Gurobi license
Dockerfile, run.sh      container that builds the authors' code; wrapper to run commands in it
scripts/make_mnist26.py rebuilds the MNIST 2-vs-6 dataset
scripts/experiment.sh   one train + attack run → results/results.csv
results/                results.csv and per-run logs (results/runs/eps<ε>_seed<s>/)
documents/              proposal and the two papers
RobustTrees/            authors' code, not in git (clone it; see SETUP.md)
gurobi/gurobi.lic       Gurobi license, not in git (you add it)
```
