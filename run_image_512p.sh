#!/bin/bash
# ============================================================
# IMAGE CUSTOMIZATION — 512×896 (single GPU, ~24 GB VRAM)
# Required models: hunyuancustom_720P (fp8) + vae_3d + llava + clip
#   Inclusi in setup_runpod.sh (default)
# ============================================================
set -e

cd /workspace/HunyuanCustom
source .venv/bin/activate

# ── Edit these ───────────────────────────────────────────────
REF_IMAGE="./assets/images/seg_woman_01.png"   # immagine di riferimento soggetto
OUTPUT_DIR="./results/image_512p"
POS_PROMPT="Realistic, High-quality. A woman is drinking coffee at a café."
NEG_PROMPT="Aerial view, aerial view, overexposed, low quality, deformation, a poor composition, bad hands, bad teeth, bad eyes, bad limbs, distortion, blurring, text, subtitles, static, picture, black border."
N_FRAMES=129    # 65 ≈ 4s | 129 ≈ 8s
SEED=1024
# ─────────────────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"

export MODEL_BASE="./models"
export DISABLE_SP=1
export PYTHONPATH=./

python hymm_sp/sample_gpu_poor.py \
    --ref-image "$REF_IMAGE" \
    --pos-prompt "$POS_PROMPT" \
    --neg-prompt "$NEG_PROMPT" \
    --ckpt ${MODEL_BASE}/hunyuancustom_720P/mp_rank_00_model_states_fp8.pt \
    --video-size 512 896 \
    --sample-n-frames $N_FRAMES \
    --cfg-scale 7.5 \
    --seed $SEED \
    --infer-steps 30 \
    --use-deepcache 1 \
    --flow-shift-eval-video 13.0 \
    --save-path "$OUTPUT_DIR" \
    --use-fp8

echo "Done! Video salvato in: $OUTPUT_DIR"
