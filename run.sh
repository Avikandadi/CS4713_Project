#!/usr/bin/env bash
# Run a command inside the robust-trees container with the repo, scripts and
# results mounted. Mounts ./gurobi/gurobi.lic if present.
#   ./run.sh                                   # interactive shell
#   ./run.sh python scripts/make_mnist26.py
#   ./run.sh bash scripts/smoke_test.sh
set -euo pipefail
cd "$(dirname "$0")"
IMAGE=${IMAGE:-robust-trees:latest}
LIC_ARGS=()
if [ -f gurobi/gurobi.lic ]; then
  LIC_ARGS=(-v "$PWD/gurobi/gurobi.lic:/opt/gurobi/gurobi.lic:ro")
fi
TTY=(); [ -t 0 ] && TTY=(-it)
exec docker run --rm ${TTY[@]+"${TTY[@]}"} \
  -v "$PWD/RobustTrees:/work/RobustTrees" \
  -v "$PWD/scripts:/work/scripts:ro" \
  -v "$PWD/results:/work/results" \
  ${LIC_ARGS[@]+"${LIC_ARGS[@]}"} \
  -w /work "$IMAGE" "${@:-bash}"
