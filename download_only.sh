#!/bin/bash
# =============================================================================
# CPU Pod — Clone repo + download modelli
# =============================================================================
# Esegui su un pod CPU economico per scaricare i modelli sul Network Volume.
#
# Usage:
#   bash download_only.sh [modelli...]
#
# Esempi:
#   bash download_only.sh                          # default: base + image-720p (~38 GB)
#   bash download_only.sh base image-720p          # image customization (~38 GB)
#   bash download_only.sh base audio-720p          # audio-driven (~38 GB)
#   bash download_only.sh base editing-720p        # video editing (~38 GB)
#   bash download_only.sh base image-720p dwpose   # image + pose (~38.3 GB)
#
# Modelli disponibili:
#   base          vae_3d + llava-llama-3-8b + clip (~18 GB)  — SEMPRE RICHIESTO
#   image-720p    hunyuancustom_720P fp8 (~20 GB)            — image/subject customization
#   audio-720p    hunyuancustom_audio_720P fp8 + whisper (~20 GB)
#   editing-720p  hunyuancustom_editing_720P fp8 (~20 GB)    — object replacement in video
#   dwpose        DWPose pose estimator (~0.3 GB)            — solo video con persone
#
# HF_TOKEN opzionale (repo pubblico):
#   export HF_TOKEN="hf_..."
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/HunyuanCustom"

# Modelli da scaricare (default se nessun argomento passato)
MODELS="${@:-base image-720p}"

echo "============================================================"
echo " HunyuanCustom — Download Models"
echo " Modelli: $MODELS"
echo "============================================================"
echo ""

# ── 1. Installa huggingface_hub ──────────────────────────────────
pip install huggingface_hub hf_transfer -q

# ── 2. Clone repo ────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/2] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/HunyuanCustom.git
else
    echo "[1/2] Repo already exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
fi

cd "$REPO_DIR"

# ── 3. Download ──────────────────────────────────────────────────
echo ""
echo "[2/2] Downloading: $MODELS"
echo "      Può richiedere 30-60 minuti."
echo ""

python download_models.py $MODELS

echo ""
echo "============================================================"
echo " Download completato!"
echo "============================================================"
echo ""
echo "Prossimo step: stoppa questo pod CPU, avvia un pod GPU"
echo "con lo stesso Network Volume, poi:"
echo "  bash setup_gpu.sh"
echo "============================================================"
