#!/usr/bin/env bash
set -euo pipefail

workspace="${CUPCAKES_OS_VM_WORKSPACE:-/var/tmp/cupcakes-os-vm-build}"
repo_dir="${CUPCAKES_OS_REPO_DIR:-$workspace/cupcakes-os}"
out_dir="${CUPCAKES_OS_OUT_DIR:-$workspace/out}"
repo_url="${CUPCAKES_OS_REPO_URL:-https://github.com/AnimatedGTVR/cupcakes-os.git}"
repo_branch="${CUPCAKES_OS_REPO_BRANCH:-main}"

if ! command -v git >/dev/null 2>&1; then
    echo "git command not found." >&2
    exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
    echo "nix command not found. Install Nix with flakes support first." >&2
    exit 1
fi

mkdir -p "$workspace"

if [[ ! -d "$repo_dir/.git" ]]; then
    git clone "$repo_url" "$repo_dir"
else
    git -C "$repo_dir" fetch origin "$repo_branch"
    git -C "$repo_dir" checkout "$repo_branch"
    git -C "$repo_dir" pull --ff-only origin "$repo_branch"
fi

cd "$repo_dir"
CUPCAKES_OS_OUT_DIR="$out_dir" ./scripts/build-iso.sh

echo
echo "Build complete."
echo "ISO output directory: $out_dir"
ls -lah "$out_dir"
