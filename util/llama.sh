#!/usr/bin/env bash
set -xeou pipefail

LBIN=$HOME/llama.cpp/build/bin

models=(
  Qwen3.6-35B-A3B-GGUF
  # Qwen3.6-27B-GGUF
  # gemma-4-26B-A4B-it-GGUF
  # gemma-4-31B-it-GGUF
  # gemma-4-E4B-it-GGUF
  # gemma-4-E2B-it-GGUF
  # Nemotron-3-Nano-30B-A3B-GGUF
)

quants=(
  # UD-Q4_K_XL
  # UD-Q5_K_XL
  # UD-Q6_K_XL
  UD-Q8_K_XL
)

for m in ${models[@]}; do
for q in ${quants[@]}; do
  echo "Starting model: $m with quant: $q"
  $LBIN/llama-bench -hf unsloth/"$m":"$q" -p 4096 -n 512
done
done

