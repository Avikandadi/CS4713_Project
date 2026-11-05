#!/usr/bin/env bash
# One experiment: train a tree ensemble on MNIST 2v6, attack it, record one CSV row.
#
#   ./run.sh bash scripts/experiment.sh <eps> <seed>
#   eps = 0 -> natural training (tree_method=exact), else robust_exact with robust_eps=eps
#
# Options (env vars):
#   NTREES=200  NPOINTS=50  ETA=0.3
#   NO_ATTACK=1    train only (accuracy goes in the CSV, distortion left blank)
#   ATTACK_ONLY=1  skip training, attack the model saved by an earlier run
# Output: results/runs/eps<eps>_seed<seed>/{train,attack}.log and a row in
# results/results.csv (one row per eps/seed/trees, updated in place).
set -euo pipefail

EPS=${1:?usage: experiment.sh <eps> <seed>}
SEED=${2:?usage: experiment.sh <eps> <seed>}
NTREES=${NTREES:-200}
NPOINTS=${NPOINTS:-50}
ETA=${ETA:-0.3}

REPO=/work/RobustTrees
NAME=eps${EPS}_seed${SEED}
OUT=/work/results/runs/$NAME
MODELS=$REPO/models/$NAME
MODEL=$(printf '%s/%04d.model' "$MODELS" "$NTREES")
CSV=/work/results/results.csv
mkdir -p "$OUT"

# No license mounted -> use gurobipy's built-in size-limited license (about 10 trees max).
[ -f "${GRB_LICENSE_FILE:-}" ] || unset GRB_LICENSE_FILE

# record key=value ... : insert or update this run's row in results.csv
record() {
  python3 - "$CSV" "$EPS" "$SEED" "$NTREES" "$@" <<'EOF'
import csv, os, sys
path, eps, seed, trees, *kv = sys.argv[1:]
cols = ["eps", "seed", "trees", "test_acc", "avg_linf", "points_attacked", "train_s", "attack_s"]
rows = list(csv.DictReader(open(path))) if os.path.exists(path) else []
row = next((r for r in rows if (r["eps"], r["seed"], r["trees"]) == (eps, seed, trees)), None)
if row is None:
    row = dict.fromkeys(cols, ""); row.update(eps=eps, seed=seed, trees=trees); rows.append(row)
row.update(k.split("=", 1) for k in kv)
w = csv.DictWriter(open(path, "w", newline=""), fieldnames=cols); w.writeheader(); w.writerows(rows)
EOF
}

# --- train (from the repo root: the conf's data paths are relative)
if [ "${ATTACK_ONLY:-0}" != 1 ]; then
  if [ "$EPS" = 0 ]; then METHOD="tree_method=exact"; else METHOD="tree_method=robust_exact robust_eps=$EPS"; fi
  echo "== $NAME: training $NTREES trees ($METHOD)"
  rm -rf "$MODELS"; mkdir -p "$MODELS"   # model_dir must exist
  START=$(date +%s)
  ( cd "$REPO" && xgboost data/binary_mnist.conf $METHOD num_round="$NTREES" eta="$ETA" \
      seed="$SEED" subsample=0.8 colsample_bytree=0.8 model_dir="$MODELS" ) > "$OUT/train.log" 2>&1
  TRAIN_S=$(( $(date +%s) - START ))
  ERR=$(grep -oE "\[$((NTREES-1))\]	test-error:[0-9.]+" "$OUT/train.log" | cut -d: -f2)
  ACC=$(python3 -c "print(round(1 - $ERR, 4))")
  echo "   test accuracy $ACC  (${TRAIN_S}s)"
  record test_acc="$ACC" train_s="$TRAIN_S"
fi
[ "${NO_ATTACK:-0}" = 1 ] && exit 0

# --- attack (from a temp dir: the script writes temporary JSON files to its cwd)
[ -f "$MODEL" ] || { echo "no model at $MODEL: train it first"; exit 1; }
echo "== $NAME: Kantchelian attack on $NPOINTS test points"
START=$(date +%s)
( cd "$(mktemp -d)" && python3 "$REPO/xgbKantchelianAttack.py" \
    -d "$REPO/data/binary_mnist0.t" -m "$MODEL" -c 2 -n "$NPOINTS" ) > "$OUT/attack.log" 2>&1 || true
ATTACK_S=$(( $(date +%s) - START ))
LINE=$(grep "average linf distortion" "$OUT/attack.log") || {
  grep -q "size-limited license" "$OUT/attack.log" \
    && echo "   Model too big for the free Gurobi license: add gurobi/gurobi.lic (see SETUP.md)," \
            "then rerun with ATTACK_ONLY=1" \
    || tail -5 "$OUT/attack.log"
  exit 1; }
LINF=$(echo "$LINE" | sed -E 's/.*distortion: ([0-9.eE+-]+).*/\1/')
POINTS=$(echo "$LINE" | sed -E 's/attacked ([0-9]+\/[0-9]+) .*/\1/')
echo "   avg l_inf distortion $LINF  ($POINTS points, ${ATTACK_S}s)"
record avg_linf="$LINF" points_attacked="$POINTS" attack_s="$ATTACK_S"
