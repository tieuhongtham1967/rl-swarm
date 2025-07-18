#!/bin/bash

set -euo pipefail

# ==== KILL PORT 3000 TRƯỚC KHI CHẠY ====
echo "Kiem tra port 3000..."
PORT_PID=$(ss -ltnp | grep ':3000' | awk -F 'pid=' '{print $2}' | cut -d',' -f1 || true)

if [ -n "$PORT_PID" ]; then
    kill -9 "$PORT_PID"
    echo "Da kill port 3000."
else
    echo "Port 3000 dang ranh."
fi

ROOT=$PWD
GENRL_TAG="v0.1.1"

export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export HUGGINGFACE_ACCESS_TOKEN="None"

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}
CPU_ONLY=true
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() { echo -e "$GREEN_TEXT$1$RESET_TEXT"; }
echo_blue() { echo -e "$BLUE_TEXT$1$RESET_TEXT"; }
echo_red() { echo -e "$RED_TEXT$1$RESET_TEXT"; }

ROOT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
mkdir -p "$ROOT/logs"

if [ "$CONNECT_TO_TESTNET" = true ]; then
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login

    # Node.js + Yarn install
    if ! command -v node > /dev/null 2>&1; then
        echo "Installing Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        echo "Installing Yarn..."
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo tee /etc/apt/trusted.gpg.d/yarn.asc > /dev/null
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list > /dev/null
        sudo apt update && sudo apt install -y yarn
    fi

    ENV_FILE="$ROOT/modal-login/.env"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi

    if [ -z "$DOCKER" ]; then
        yarn install --immutable
        echo "Building server"
        yarn build > "$ROOT/logs/yarn.log" 2>&1
    fi

    echo_green ">> Starting backend server (modal-login)"
    yarn start >> "$ROOT/logs/yarn.log" 2>&1 &
    SERVER_PID=$!
    echo "Started server process: $SERVER_PID"
    sleep 5

    # Check for existing login
    if ls "$ROOT"/modal-login/temp-data/user*.json 1> /dev/null 2>&1; then
        echo_green ">> Modal login already detected. Skipping ngrok."
    else
        echo ">> No modal login found. Starting ngrok for login..."

        if ! command -v ngrok &> /dev/null; then
            echo ">> Installing ngrok..."
            curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null
            echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list > /dev/null
            sudo apt update > /dev/null
            sudo apt install -y ngrok > /dev/null
        fi

        # 💡 CHỈ yêu cầu token nếu chưa config ngrok
        if [ ! -f "$HOME/.config/ngrok/ngrok.yml" ]; then
            echo ">> ngrok chua cau hinh."
            read -p ">> Nhap token ngrok: " NGROK_TOKEN
            ngrok config add-authtoken "$NGROK_TOKEN"
        else
            echo_green ">> ngrok da duoc cau hinh"
        fi

        nohup ngrok http 3000 > /dev/null 2>&1 &
        sleep 3

        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels \
            | grep -o '"public_url":"https:[^"]*' \
            | cut -d '"' -f4)

        echo_green ">> Open http://localhost:3000."
        if [ -n "$NGROK_URL" ]; then
            echo_green ">> Truy cap tu xa qua ngrok: $NGROK_URL"
        else
            echo_red ">> Khong lay duoc dia chi ngrok public."
        fi
    fi

    cd "$ROOT"

    echo_green ">> Dang cho tao file userData.json..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 5
    done

    echo "Da tim thay userData.json. Tiep tuc..."
    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "ORG_ID của bạn: $ORG_ID"

    echo "Cho kich hoat API key..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "API key da duoc kich hoat!"
            break
        else
            echo "Cho kich hoat API key..."
            sleep 5
        fi
    done
fi

echo_green ">> Cai dat thu vien Python..."
pip install --upgrade pip
pip install gensyn-genrl==0.1.4
pip install reasoning-gym>=0.1.20
pip install trl
pip install hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd

if [ ! -d "$ROOT/configs" ]; then
    mkdir "$ROOT/configs"
fi

cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"

if [ -n "$DOCKER" ]; then
    sudo chmod -R 0777 /home/gensyn/rl_swarm/configs
fi

MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct"
echo_green ">> $MODEL_NAME"
export MODEL_NAME

echo_green ">> Khoi chay rl-swarm..."

python3 -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/rgym_exp/config" \
    --config-name "rg-swarm.yaml"

wait
