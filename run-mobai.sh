#!/usr/bin/env bash
set -euo pipefail

# Avoid a blank WebKitGTK window on this Linux graphics setup.
export WEBKIT_DISABLE_DMABUF_RENDERER=1
exec mobai "$@"
