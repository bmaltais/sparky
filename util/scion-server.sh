#!/usr/bin/env bash
set -eou pipefail

scion server start \
  --host 0.0.0.0 \
  --enable-hub \
  --enable-web --web-port 9810 \
  --enable-runtime-broker \
  --foreground