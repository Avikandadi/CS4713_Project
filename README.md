# Does Robust Training Protect Trees from Poisoning?

CS 4713/5713, Fall 2026. Avinash Kandadi and Thomas Petersen.
Status as of the midterm checkpoint, Nov 5, 2026. See `documents/Project_Proposal.pdf` for the
proposal and `SETUP.md` for how to run the code.

## Project idea

Chen et al. (2019) train decision trees that are hard to fool with small changes to test inputs.
Shafahi et al. (2018) show that a few poisoned training images can make a model misclassify a chosen
test image. We want to know if robust trees are also harder to poison.

We train normal and robust XGBoost trees on MNIST 2 vs. 6 with robustness ε = 0, 0.1, 0.2, 0.3
(ε = 0 is a normal tree), poison them with 1 to 50 images per target, and measure how often the
attack works.

## What is done

**Setup.** The authors' RobustTrees code builds and runs in Docker. On a Mac it needed two build
flags: `USE_SSE=0`, and `-fsigned-char`, without which the program ran out of memory before training.

**Dataset.** The authors' download links are dead, so we rebuilt MNIST 2 vs. 6 from the original
MNIST files. It has 11,876 training and 1,990 test images, the same as the paper.

**First result.** Robust trees are much harder to fool, with almost no loss in accuracy:

| model (10 trees) | test accuracy | avg change needed to fool it |
|---|---|---|
| normal (ε = 0) | 0.9925 | 0.076 |
| robust (ε = 0.3) | 0.9894 | 0.299 |
| paper, normal (1000 trees) | 0.998 | 0.064 |
| paper, robust (1000 trees) | 0.997 | 0.315 |

The robust model needs about 4 times more change to be fooled. This matches the paper.

**Experiment script.** `scripts/experiment.sh <eps> <seed>` trains one model, attacks it, and saves
the result to `results/results.csv`.

## Midterm checklist

- Done: set up the code and confirm robust trees are harder to fool.
- In progress: compare normal and robust trees across ε with several seeds. The script is ready,
  but the attack needs a full Gurobi license.
- Not started: one poisoning sanity check.
- In progress: midterm figure and table. The table above is a first version.

## Problems so far

- The Mac build needed extra flags (above).
- Newer XGBoost versions can't open the old model files, so we use version 1.7.6.
- The authors' data links are dead, so we rebuilt the dataset.
- The free Gurobi license only works on very small models (about 10 trees). We need the free
  academic license, which requires the campus network or VPN to sign up. Until then we can train
  models and attack them later.

## Next steps

Before the midterm report:
1. Get the Gurobi academic license.
2. Run ε = 0, 0.1, 0.2, 0.3 with 3 seeds each (12 models) and make the figure and table.
3. Run one small poisoning test on a normal and a robust model.

Nov 6 to Nov 25: run the full poisoning study (ε = 0 to 0.3, 1 to 50 poisons per target, 50
targets), and compare poisons made from one base image vs. many.

Nov 26 to Dec 14: analysis, talks on Dec 8 and Dec 10, and the final report and code due Dec 14.

## Files

- `README.md`: this file
- `SETUP.md`: how to build and run everything, and how to get the Gurobi license
- `Dockerfile`, `run.sh`: the container and a script to run commands in it
- `scripts/make_mnist26.py`: rebuilds the dataset
- `scripts/experiment.sh`: trains and attacks one model
- `results/`: results and logs
- `documents/`: the proposal and the two papers
- `RobustTrees/`: the authors' code (not in git, see `SETUP.md`)
