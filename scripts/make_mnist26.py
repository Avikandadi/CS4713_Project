#!/usr/bin/env python3
"""Rebuild the MNIST 2-vs-6 binary dataset used by Chen et al. (ICML 2019).

* digit 2 -> label 0, digit 6 -> label 1
* pixels scaled to [0, 1] (x / 255)
* dense, 1-indexed LIBSVM with EVERY feature written, including zeros.
  The RobustTrees README warns that omitted zeros are treated as missing
  values, which breaks robust training.
* outputs: <repo>/data/binary_mnist0 (train) and <repo>/data/binary_mnist0.t (test)

Raw MNIST .gz files are cached in <repo>/data/mnist_raw/, so reruns are offline.

Expected counts (paper): train 11,876 (5,958 twos / 5,918 sixes),
                         test   1,990 (1,032 twos /   958 sixes).
"""
import argparse
import gzip
import os
import struct
import sys
import urllib.request

import numpy as np

FILES = {
    "train_images": "train-images-idx3-ubyte.gz",
    "train_labels": "train-labels-idx1-ubyte.gz",
    "test_images": "t10k-images-idx3-ubyte.gz",
    "test_labels": "t10k-labels-idx1-ubyte.gz",
}
MIRRORS = [
    "https://raw.githubusercontent.com/fgnt/mnist/master/",
    "https://ossci-datasets.s3.amazonaws.com/mnist/",
    "https://storage.googleapis.com/cvdf-datasets/mnist/",
]
EXPECTED = {"train": (11876, 5958, 5918), "test": (1990, 1032, 958)}


def fetch(name, cache_dir):
    path = os.path.join(cache_dir, name)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    os.makedirs(cache_dir, exist_ok=True)
    errors = []
    for base in MIRRORS:
        url = base + name
        try:
            print(f"downloading {url}")
            req = urllib.request.Request(url, headers={"User-Agent": "mnist26-rebuild"})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            gzip.decompress(data)  # validate before caching
            tmp = path + ".part"
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, path)
            return path
        except Exception as e:  # try next mirror
            errors.append(f"{url}: {e}")
    sys.exit("failed to download " + name + ":\n  " + "\n  ".join(errors))


def read_idx(path):
    with gzip.open(path, "rb") as f:
        magic = struct.unpack(">I", f.read(4))[0]
        ndim = magic & 0xFF
        dims = struct.unpack(">" + "I" * ndim, f.read(4 * ndim))
        return np.frombuffer(f.read(), dtype=np.uint8).reshape(dims)


def write_libsvm(path, X, y):
    # Every feature written explicitly (1-indexed), zeros included.
    idx = [str(j + 1) + ":" for j in range(X.shape[1])]
    tmp = path + ".part"
    with open(tmp, "w") as f:
        for row, label in zip(X, y):
            vals = ["0" if v == 0 else f"{v:.6g}" for v in row]
            f.write(str(int(label)) + " " + " ".join(i + v for i, v in zip(idx, vals)) + "\n")
    os.replace(tmp, path)


def build(split, images, labels, out_path):
    X = read_idx(images).reshape(-1, 784)
    y = read_idx(labels)
    keep = (y == 2) | (y == 6)
    X = X[keep].astype(np.float64) / 255.0
    y = (y[keep] == 6).astype(int)
    write_libsvm(out_path, X, y)
    n, n0, n1 = len(y), int((y == 0).sum()), int((y == 1).sum())
    ok = (n, n0, n1) == EXPECTED[split]
    print(f"{split:5s}: {n:6d} rows  (label0/digit2={n0}, label1/digit6={n1})  "
          f"expected {EXPECTED[split]}  -> {'OK' if ok else 'MISMATCH'}  [{out_path}]")
    return ok


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.path.join(here, "..", "RobustTrees"))
    args = ap.parse_args()
    data_dir = os.path.join(os.path.abspath(args.repo), "data")
    cache = os.path.join(data_dir, "mnist_raw")
    p = {k: fetch(v, cache) for k, v in FILES.items()}
    ok = build("train", p["train_images"], p["train_labels"], os.path.join(data_dir, "binary_mnist0"))
    ok &= build("test", p["test_images"], p["test_labels"], os.path.join(data_dir, "binary_mnist0.t"))
    if not ok:
        sys.exit("row counts do not match the paper")
    print("dataset OK")


if __name__ == "__main__":
    main()
