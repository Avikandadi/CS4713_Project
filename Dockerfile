# RobustTrees (Chen et al., ICML 2019) reproduction environment.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git python3 python3-venv python3-pip ca-certificates time \
    && rm -rf /var/lib/apt/lists/*

# Build the fork from a copy of the repo baked into the image. The repo is ALSO
# mounted at /work/RobustTrees at runtime (for data/models); the mount would hide
# a binary built there, so the CLI is installed to /usr/local/bin/xgboost.
# ARM64 needs two build flags (no source changes):
#   USE_SSE=0                  -msse2 is x86-only.
#   ADD_CFLAGS=-fsigned-char   plain `char` is UNSIGNED on aarch64. The .conf
#       reader (src/common/config.h) stores chars in `char ch_buf_` and compares
#       with EOF (-1), which never matches -> infinite loop that eats all RAM
#       before training starts. -fsigned-char restores x86 semantics.
COPY RobustTrees /opt/RobustTrees-build
WORKDIR /opt/RobustTrees-build
RUN ARCH="$(uname -m)"; \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then SSE="USE_SSE=0 ADD_CFLAGS=-fsigned-char"; else SSE=""; fi; \
    echo "Building for $ARCH with flags: $SSE"; \
    make -j"$(nproc)" $SSE \
    && test -x ./xgboost \
    && grep -q robust_exact src/learner.cc \
    && install -m 755 ./xgboost /usr/local/bin/xgboost \
    && /usr/local/bin/xgboost 2>&1 | head -3

# Python side: xgboost 1.7.6 is the newest version that still loads the fork's
# v0.72 binary .model files (2.x+ fails with "Check failed: str[0] == '{'").
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir \
        xgboost==1.7.6 numpy scipy scikit-learn gurobipy pandas matplotlib
ENV PATH=/opt/venv/bin:$PATH

# Full Gurobi license (Academic WLS) is mounted here; see SETUP.md.
ENV GRB_LICENSE_FILE=/opt/gurobi/gurobi.lic

WORKDIR /work
CMD ["bash"]
