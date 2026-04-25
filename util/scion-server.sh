#!/usr/bin/env bash
set -eou pipefail

scion server start \
  --host 0.0.0.0 \
  --web-port 9810 \
  --foreground