#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

case "${1:-}" in
  --withoutSC|--without-sc)
    shift
    exec builder ios build --profile preview --unsigned "$@"
    ;;
  -h|--help)
    echo 'Usage: ./build.sh [--withoutSC] [builder ios build options]'
    echo '  --withoutSC  Preview without Screen Time; sign on install with your free Apple ID.'
    exit 0
    ;;
  *) exec builder ios build --unsigned "$@" ;;
esac
