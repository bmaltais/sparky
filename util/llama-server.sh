#!/usr/bin/env bash
set -eou pipefail

LBIN=$HOME/llama.cpp/build/bin

models=(
  # Qwen3.6-27B-GGUF
  Qwen3.6-35B-A3B-GGUF
  # gemma-4-31B-it-GGUF
  # gemma-4-26B-A4B-it-GGUF
  # gemma-4-E4B-it-GGUF
  # gemma-4-E2B-it-GGUF
  # Nemotron-3-Nano-30B-A3B-GGUF
)

quants=(
  UD-Q8_K_XL
  # UD-Q6_K_XL
  # UD-Q5_K_XL
  # UD-Q4_K_XL
)



m=${models[0]}
q=${quants[0]}
echo "Starting: $m @ $q"
$LBIN/llama-server \
  -hf unsloth/"$m":"$q" \
  --host 0.0.0.0 \
  --port 8080
