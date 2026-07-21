#!/usr/bin/env bash
set -euo pipefail

case "${1:-help}" in
    apps)
        shift
        exec cupcakes-os-apps "$@"
        ;;
    config)
        shift
        exec cupcakes-os-config "$@"
        ;;
    desktop)
        shift
        exec cupcakes-os-desktop "$@"
        ;;
    doctor)
        shift
        exec cupcakes-os-doctor "$@"
        ;;
    check-full)
        shift
        exec cupcakes-os-check-full "$@"
        ;;
    recovery)
        shift
        exec cupcakes-os-recovery "$@"
        ;;
    repair)
        shift
        case "${1:-}" in
            --mango|mango)
                exec cupcakes-os-repair-flake-purity --mango
                ;;
            help|--help|-h|"")
                cat <<'EOF'
Cupcakes OS repair commands:
  cupcakes-os repair --mango    repair MangoWM flake-pure config paths
EOF
                ;;
            *)
                printf 'Unknown Cupcakes OS repair command: %s\n' "$1" >&2
                exit 1
                ;;
        esac
        ;;
    welcome)
        shift
        exec cupcakes-os-welcome "$@"
        ;;
    hardware-test)
        shift
        exec cupcakes-os-hardware-test "$@"
        ;;
    support-report)
        shift
        exec cupcakes-os-support-report "$@"
        ;;
    update)
        shift
        exec cupcakes-os-update "$@"
        ;;
    fallback)
        shift
        exec cupcakes-os-update fallback "$@"
        ;;
    help|--help|-h|"")
        cat <<'EOF'
Cupcakes OS commands:
  cupcakes-os welcome          first-boot welcome and quick actions
  cupcakes-os doctor           check Cupcakes OS system health
  cupcakes-os check-full       collect full ANIX, TinyPM, desktop, driver, and Nix logs
  cupcakes-os recovery         rollback, repair, and diagnostics menu
  cupcakes-os repair --mango   repair MangoWM flake-pure config paths
  cupcakes-os desktop          view or switch desktop profiles
  cupcakes-os apps             install curated apps
  cupcakes-os config           view or edit installed-system settings
  cupcakes-os update           update Cupcakes OS
  cupcakes-os fallback         intentionally switch to an older release
  cupcakes-os hardware-test    run hardware readiness checks
  cupcakes-os support-report   collect support diagnostics
EOF
        ;;
    *)
        printf 'Unknown Cupcakes OS command: %s\n' "$1" >&2
        exit 1
        ;;
esac
