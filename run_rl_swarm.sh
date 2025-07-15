#!/bin/bash
set -euo pipefail

ROOT=$PWD
export ROOT
export CONNECT_TO_TESTNET=true
export CPU_ONLY=true
export HF_HUB_DOWNLOAD_TIMEOUT=120
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export HUGGINGFACE_ACCESS_TOKEN="None"
export MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct"

# Set default identity path
DEFAULT_IDENTITY_PATH="$ROOT/swarm.pem"
export IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

# Extract ORG_ID from temp-data if not set
export ORG_ID=${ORG_ID:-$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' "$ROOT/modal-login/temp-data/userData.json")}

# Optional: print info
echo "ORG_ID: $ORG_ID"
echo "MODEL: $MODEL_NAME"

# Run the RL Swarm launcher
python3 -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/rgym_exp/config" \
    --config-name "rg-swarm.yaml"
