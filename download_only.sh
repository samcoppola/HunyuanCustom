#!/bin/bash
# =============================================================================
# CPU Pod — Clone repo + download models ONLY
# =============================================================================
# Esegui su un pod CPU economico per scaricare i modelli sul Network Volume.
# Non crea venv, non installa dipendenze — solo git clone + download.
#
# Usage:
#   export HF_TOKEN="hf_..."   # opzionale
#   bash download_only.sh
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/HunyuanCustom"

echo "============================================================"
echo " HunyuanCustom — Download Models (CPU pod)"
echo "============================================================"

# ── 1. Installa huggingface_hub (minimo necessario per il download) ──
pip install huggingface_hub -q

# ── 2. Clone repo ────────────────────────────────────────────────────
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

# ── 3. Download models ────────────────────────────────────────────────
echo ""
echo "[2/2] Downloading models (base + image-720p, ~38 GB)..."
echo "      Può richiedere 30-60 minuti."
echo ""

python download_models.py base image-720p

echo ""
echo "============================================================"
echo " Download completato!"
echo "============================================================"
echo ""
echo "Prossimo step: stoppa questo pod CPU e avvia un pod GPU"
echo "con lo stesso Network Volume, poi:"
echo "  bash setup_gpu.sh"
echo "============================================================"
