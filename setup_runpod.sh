#!/bin/bash
# =============================================================================
# RunPod Setup Script — HunyuanCustom
# =============================================================================
# Run once dopo aver attivato il pod (Network Volume montato su /workspace).
# Usage:
#   bash setup_runpod.sh
#
# What it does:
#   1. Clona il repo (o fa pull se già presente)
#   2. Crea un Python 3.10 venv e installa le dipendenze
#   3. Scarica i modelli per image customization (base + image-720p, ~38 GB)
#
# Per scaricare modelli diversi, usa direttamente download_models.py:
#   python download_models.py base audio-720p
#   python download_models.py base editing-720p
#
# Requirements:
#   - Network Volume montato su /workspace
#   - (Opzionale) HuggingFace token: export HF_TOKEN="hf_..."
# =============================================================================

set -e

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/HunyuanCustom"

echo "============================================================"
echo " HunyuanCustom — RunPod Setup"
echo "============================================================"

# ── 1. Clone repo ────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/3] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/HunyuanCustom.git
else
    echo "[1/3] Repo already exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
fi

cd "$REPO_DIR"

# ── 2. Create venv and install dependencies ───────────────────────
echo ""
echo "[2/3] Setting up Python virtual environment..."

if ! command -v python3.10 &>/dev/null; then
    apt-get install -y python3.10 python3.10-venv
fi

if [ ! -d ".venv" ]; then
    python3.10 -m venv .venv
fi

source .venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt

# Flash-attention: opzionale, raccomandato per A100/H100 (compila in 30+ min).
# Non necessario su GPU consumer con --use-fp8.
if [ "${INSTALL_FLASH_ATTN:-false}" = "true" ]; then
    echo "    Installing flash-attention (30+ min)..."
    pip install ninja
    pip install git+https://github.com/Dao-AILab/flash-attention.git@v2.6.3
fi

echo "    Dipendenze installate."

# ── 3. Download models ────────────────────────────────────────────
echo ""
echo "[3/3] Downloading models (base + image-720p, ~38 GB)..."
echo "      Può richiedere 30-60 minuti."
echo ""

python download_models.py base image-720p

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Setup complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Carica l'immagine di riferimento (es. appia_strada.png)"
echo "     tramite Jupyter in /workspace/HunyuanCustom/"
echo ""
echo "  2. Esegui la generazione:"
echo "     Via Appia preconfigurato:        bash run_via_appia_custom.sh"
echo "     Image customization 512p (24GB): bash run_image_512p.sh"
echo "     Image customization 720p (40GB): bash run_image_720p.sh"
echo ""
echo "  3. Per altri modelli:"
echo "     python download_models.py base audio-720p    # audio-driven"
echo "     python download_models.py base editing-720p  # video editing"
echo ""
echo "  Output video in: $REPO_DIR/results/"
echo "============================================================"
