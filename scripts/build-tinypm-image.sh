#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$repo_dir"

cupcakes_os_version="$(tr -d '\n' < VERSION | tr -cd '[:alnum:]._-')"
[[ -n "$cupcakes_os_version" ]] || cupcakes_os_version="unknown"

tinypm_version="$(
  awk -F'"' '/^tinypm_version=/{print $2; exit}' vendor/tinypm/lib/core/common.sh
)"
tinypm_version="$(printf '%s' "${tinypm_version:-unknown}" | tr -cd '[:alnum:]._-')"
[[ -n "$tinypm_version" ]] || tinypm_version="unknown"

image_name="${1:-${IMAGE_NAME:-cupcakes-os-tinypm:${tinypm_version}-cupcakes-os-${cupcakes_os_version}}}"

docker build \
  --file packaging/tinypm/Dockerfile \
  --build-arg TINYPM_VERSION="$tinypm_version" \
  --build-arg CUPCAKES_OS_VERSION="$cupcakes_os_version" \
  --build-arg IMAGE_SOURCE="https://github.com/AnimatedGTVR/cupcakes-os" \
  --tag "$image_name" \
  vendor/tinypm

printf 'Built TinyPM image: %s\n' "$image_name"
printf 'Try it with: docker run --rm %s Parcel --version\n' "$image_name"
printf 'The full TinyPM project lives at: /opt/tinypm/project\n'
