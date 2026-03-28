#!/bin/bash
# ============================================================
# VIDEO EDITING (object replacement) — 720×1280 (single GPU)
# Required models: hunyuancustom_editing_720P (fp8) + vae_3d + llava + clip
#   Per scaricare: rimuovi "models/hunyuancustom_editing_720P/*" da
#                  ignore_patterns in setup_runpod.sh e rilancia il setup.
#
# Come funziona:
#   Sostituisce un oggetto/soggetto in un video con quello di --ref-image.
#   Richiede un video di background (--input-video) e una mask (--mask-video)
#   che indica dove si trova l'oggetto da sostituire (bianco = oggetto, nero = sfondo).
# ============================================================
set -e

cd /workspace/HunyuanCustom
source .venv/bin/activate

# ── Edit these ───────────────────────────────────────────────
REF_IMAGE="./assets/images/sed_red_panda.png"          # soggetto da inserire
INPUT_VIDEO="./assets/input_videos/001_bg.mp4"         # video di sfondo
MASK_VIDEO="./assets/input_videos/001_mask.mp4"        # maschera dell'area da sostituire
OUTPUT_DIR="./results/editing_720p"
POS_PROMPT="Realistic, High-quality. A red panda is walking on a stone road."
NEG_PROMPT="Aerial view, aerial view, overexposed, low quality, deformation, a poor composition, bad hands, bad teeth, bad eyes, bad limbs, distortion, blurring, text, subtitles, static, picture, black border."
EXPAND_SCALE=5    # scala di espansione della maschera
SEED=1024
# ─────────────────────────────────────────────────────────────

if [ ! -f "$INPUT_VIDEO" ]; then
    echo "ERROR: Video non trovato: $INPUT_VIDEO"
    exit 1
fi
if [ ! -f "$MASK_VIDEO" ]; then
    echo "ERROR: Mask video non trovato: $MASK_VIDEO"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

export MODEL_BASE="./models"
export DISABLE_SP=1
export PYTHONPATH=./

python hymm_sp/sample_gpu_poor.py \
    --video-condition \
    --ref-image "$REF_IMAGE" \
    --input-video "$INPUT_VIDEO" \
    --mask-video "$MASK_VIDEO" \
    --expand-scale $EXPAND_SCALE \
    --pos-prompt "$POS_PROMPT" \
    --neg-prompt "$NEG_PROMPT" \
    --ckpt ${MODEL_BASE}/hunyuancustom_editing_720P/mp_rank_00_model_states_fp8.pt \
    --cfg-scale 7.5 \
    --seed $SEED \
    --infer-steps 50 \
    --use-deepcache 1 \
    --flow-shift-eval-video 5.0 \
    --save-path "$OUTPUT_DIR" \
    --use-fp8
    # Aggiungi --pose-enhance per video con persone (migliora la qualità della posa)

echo "Done! Video salvato in: $OUTPUT_DIR"
