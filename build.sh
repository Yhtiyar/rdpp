#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

release=false
without_sc=false
custom_profile=false
args=()
while (($#)); do
  case "$1" in
    --release) release=true ;;
    --withoutSC|--without-sc) without_sc=true ;;
    -h|--help)
      echo 'Usage: ./build.sh [--release] [--withoutSC] [builder ios build options]'
      echo '  --release    Build for standalone use without a connected debugger.'
      echo '  --withoutSC  Preview without Screen Time; sign on install with your free Apple ID.'
      exit 0
      ;;
    --profile|--profile=*) custom_profile=true; args+=("$1") ;;
    --) args+=("$@"); break ;;
    *) args+=("$1") ;;
  esac
  shift
done

profile=''
if "$without_sc"; then
  profile=preview
  if "$release"; then profile=preview-release; fi
elif "$release"; then
  profile=release
fi

if [[ -n "$profile" ]]; then
  if "$custom_profile"; then
    echo 'Cannot combine --profile with --release or --withoutSC; choose one profile selection method.' >&2
    exit 2
  fi
  exec builder ios build --unsigned --profile "$profile" "${args[@]}"
fi
exec builder ios build --unsigned "${args[@]}"
