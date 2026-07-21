#!/usr/bin/env bash
set -euo pipefail

config_dir="${CUPCAKES_OS_SYSTEM_CONFIG:-/etc/nixos}"
cupcakes_os_dir="$config_dir/cupcakes-os"
mango_dir="$cupcakes_os_dir/mango"
mango_config="$mango_dir/config.conf"
bad_mango_store='/nix/store/assets/mango/config.conf'

usage() {
    cat <<'EOF'
Usage: cupcakes-os-repair-flake-purity [--mango]

Repairs installed Cupcakes OS flake paths that can break pure evaluation.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ "$(id -u)" -ne 0 && ( "$config_dir" == "/etc/nixos" || ! -w "$config_dir" ) ]]; then
    exec sudo env CUPCAKES_OS_SYSTEM_CONFIG="$config_dir" bash "$0" "$@"
fi

mkdir -p "$mango_dir"

if [[ ! -f "$mango_config" ]]; then
    for candidate in \
        "$config_dir/.cupcakes-os-upstream/assets/mango/config.conf" \
        /etc/cupcakes-os/mango/config.conf \
        "$config_dir/assets/mango/config.conf"; do
        if [[ -f "$candidate" ]]; then
            cp "$candidate" "$mango_config"
            break
        fi
    done
fi

if [[ ! -f "$mango_config" ]]; then
    : > "$mango_config"
fi

rewrite_mango_path() {
    local file="$1"
    local replacement="$2"

    [[ -f "$file" ]] || return 0
    sed -i \
        -e "s|\"${bad_mango_store}\"|${replacement}|g" \
        -e "s|${bad_mango_store}|${replacement}|g" \
        -e "s|../../assets/mango/config\\.conf|${replacement}|g" \
        -e "s|../../../assets/mango/config\\.conf|${replacement}|g" \
        "$file"
}

rewrite_mango_path "$cupcakes_os_dir/cupcakes-os-options.nix" './mango/config.conf'
rewrite_mango_path "$cupcakes_os_dir/installed-base.nix" './mango/config.conf'

if [[ -d "$cupcakes_os_dir/desktops" ]]; then
    while IFS= read -r -d '' file; do
        rewrite_mango_path "$file" '../mango/config.conf'
    done < <(
        grep -RIlZ \
            -e "$bad_mango_store" \
            -e '../../assets/mango/config.conf' \
            -e '../../../assets/mango/config.conf' \
            "$cupcakes_os_dir/desktops" 2>/dev/null || true
    )
fi

if git -C "$config_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$config_dir" add \
        cupcakes-os/mango/config.conf \
        cupcakes-os/cupcakes-os-options.nix \
        cupcakes-os/installed-base.nix \
        cupcakes-os/desktops/mangowm.nix \
        2>/dev/null || true
fi

printf 'Cupcakes OS MangoWM flake purity repair complete.\n'
printf 'Mango config asset: %s\n' "$mango_config"
printf '\nRun:\n'
printf '  sudo nixos-rebuild switch --flake %s#cupcakes-os\n' "$config_dir"
