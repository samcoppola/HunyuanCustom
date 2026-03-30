#!/bin/bash
# =============================================================================
# GPU Pod — Installa dipendenze (venv + torch CUDA + requirements)
# =============================================================================
# Esegui sul pod GPU dopo aver scaricato i modelli con download_only.sh.
# Crea il venv sul pod GPU così torch eredita il CUDA corretto.
#
# Usage:
#   cd /workspace/HunyuanCustom
#   bash setup_gpu.sh
# =============================================================================

set -e

REPO_DIR="/workspace/HunyuanCustom"
cd "$REPO_DIR"

echo "============================================================"
echo " HunyuanCustom — GPU Setup (venv + dipendenze)"
echo "============================================================"

# ── 1. Rileva versione CUDA ────────────────────────────────────────
if command -v nvcc &>/dev/null; then
    CUDA_VER=$(nvcc --version | grep "release" | sed 's/.*release //' | sed 's/,.*//' | cut -d. -f1,2)
    echo "[1/3] CUDA rilevata: $CUDA_VER"
else
    echo "[1/3] nvcc non trovato — uso CUDA 12.4 come default"
    CUDA_VER="12.4"
fi

# Mappa versione CUDA → wheel PyTorch
case "$CUDA_VER" in
    11.8) TORCH_INDEX="https://download.pytorch.org/whl/cu118" ;;
    12.1) TORCH_INDEX="https://download.pytorch.org/whl/cu121" ;;
    12.4) TORCH_INDEX="https://download.pytorch.org/whl/cu124" ;;
    *)    TORCH_INDEX="https://download.pytorch.org/whl/cu124" ;;
esac

# ── 2. Crea venv ──────────────────────────────────────────────────
echo ""
echo "[2/3] Creazione venv Python..."

if ! command -v python3.10 &>/dev/null; then
    apt-get install -y python3.10 python3.10-venv
fi

if [ ! -d ".venv" ]; then
    python3.10 -m venv .venv
    echo "    Venv creato."
else
    echo "    Venv già esistente."
fi

source .venv/bin/activate

# ── 3. Installa dipendenze ─────────────────────────────────────────
echo ""
echo "[3/3] Installazione dipendenze (torch CUDA + requirements)..."

pip install --upgrade pip -q

# Torch con CUDA — versione compatibile con HunyuanCustom
pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url "$TORCH_INDEX" -q

# Resto delle dipendenze
pip install -r requirements.txt

# Flash-attention opzionale (30+ min di compilazione, solo A100/H100)
if [ "${INSTALL_FLASH_ATTN:-false}" = "true" ]; then
    echo "    Installing flash-attention (30+ min)..."
    pip install ninja
    pip install git+https://github.com/Dao-AILab/flash-attention.git@v2.6.3
fi

# ── Verifica torch+CUDA ───────────────────────────────────────────
echo ""
echo "Verifica torch + CUDA:"
python -c "import torch; print(f'  torch={torch.__version__}  CUDA={torch.cuda.is_available()}  device={torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " GPU setup completato!"
echo "============================================================"
echo ""
echo "Carica appia_strada.png via Jupyter, poi:"
echo "  bash run_via_appia_custom.sh"
echo "============================================================"
