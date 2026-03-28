#!/bin/bash
# =============================================================================
# RunPod Setup Script — HunyuanCustom
# =============================================================================
# Run once after aver attivato il pod (Network Volume montato su /workspace).
# Usage:
#   bash setup_runpod.sh
#
# What it does:
#   1. Clona il repo ufficiale Tencent (o fa pull se già presente)
#   2. Crea un Python venv e installa le dipendenze
#   3. Scarica i pesi del modello da HuggingFace
#
# Requirements:
#   - Network Volume montato su /workspace
#   - (Opzionale) HuggingFace token: export HF_TOKEN="hf_..."
# =============================================================================

set -e  # Exit on error

WORKSPACE="/workspace"
REPO_DIR="$WORKSPACE/HunyuanCustom"
HF_REPO="tencent/HunyuanCustom"

echo "============================================================"
echo " HunyuanCustom — RunPod Setup"
echo "============================================================"

# ── 1. Clone repo ────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/4] Cloning repo..."
    cd "$WORKSPACE"
    git clone https://github.com/samcoppola/HunyuanCustom.git
else
    echo "[1/4] Repo already exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
fi

cd "$REPO_DIR"

# ── 2. Create venv and install dependencies ───────────────────────
echo ""
echo "[2/4] Setting up Python virtual environment..."

if ! command -v python3.10 &>/dev/null; then
    apt-get install -y python3.10 python3.10-venv
fi

PYTHON=python3.10

if [ ! -d ".venv" ]; then
    $PYTHON -m venv .venv
fi

source .venv/bin/activate

pip install --upgrade pip -q
pip install -r requirements.txt

# Flash-attention: compilazione opzionale (30+ min), raccomandato per A100/H100.
# Su GPU consumer con poca VRAM, puoi skippare e usare --use-fp8 --cpu-offload.
if [ "${INSTALL_FLASH_ATTN:-false}" = "true" ]; then
    echo "    Installing flash-attention (this may take 30+ minutes)..."
    pip install ninja
    pip install git+https://github.com/Dao-AILab/flash-attention.git@v2.6.3
fi

echo "    Dependencies installed."

# ── 3. Download model weights ─────────────────────────────────────
echo ""
echo "[3/4] Downloading model weights..."
echo "      Stima: ~45 GB (720P fp8 + vae + llava + clip)."
echo "      Può richiedere 30-60 minuti."

"$REPO_DIR/.venv/bin/python" - <<'PYEOF'
import os
from huggingface_hub import snapshot_download

repo_id = "tencent/HunyuanCustom"
local_dir = "/workspace/HunyuanCustom"
token = os.environ.get("HF_TOKEN", None)

# Scarica solo il necessario per la customizzazione immagine singola (720P fp8).
# Rimuovi i pattern corrispondenti per aggiungere audio/editing in futuro.
ignore_patterns = [
    "models/hunyuancustom_audio_720P/*",    # modello audio-driven (non necessario)
    "models/hunyuancustom_editing_720P/*",  # modello video-editing (non necessario)
    "models/whisper-tiny/*",                # encoder audio (non necessario)
    "models/DWPose/*",                      # pose estimation (solo per video umani)
    # Incluso: hunyuancustom_720P (fp8), vae_3d, llava-llama-3-8b-v1_1, openai_clip
]

print(f"Downloading to: {local_dir}")
print("Incluso: hunyuancustom_720P (fp8), vae_3d, llava-llama-3-8b-v1_1, openai_clip")
print("Skippato: audio model, editing model, DWPose, whisper")
print()

snapshot_download(
    repo_id=repo_id,
    local_dir=local_dir,
    ignore_patterns=ignore_patterns,
    token=token,
    local_dir_use_symlinks=False,
)

print("Download complete!")
PYEOF

# ── 4. Verify structure ───────────────────────────────────────────
echo ""
echo "[4/4] Verifying checkpoint structure..."

"$REPO_DIR/.venv/bin/python" - <<'PYEOF'
import os

base = "/workspace/HunyuanCustom/models"
required = [
    "hunyuancustom_720P/mp_rank_00_model_states_fp8.pt",
    "vae_3d",
    "llava-llama-3-8b-v1_1",
    "openai_clip-vit-large-patch14",
]

all_ok = True
for path in required:
    full = os.path.join(base, path)
    status = "OK" if os.path.exists(full) else "MISSING"
    if status == "MISSING":
        all_ok = False
    print(f"  [{status}] {path}")

if all_ok:
    print("\nAll required files found. Ready to generate!")
else:
    print("\nSome files are missing. Check the download logs above.")
PYEOF

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
echo "     Image customization 512p (24GB): bash run_image_512p.sh"
echo "     Image customization 720p (40GB): bash run_image_720p.sh"
echo "     Via Appia preconfigurato:        bash run_via_appia_custom.sh"
echo ""
echo "  3. Output video in: $REPO_DIR/results/"
echo ""
echo "  Per scaricare i modelli audio/editing in futuro:"
echo "  Rimuovi i relativi pattern in ignore_patterns e rilancia il setup."
echo "============================================================"
