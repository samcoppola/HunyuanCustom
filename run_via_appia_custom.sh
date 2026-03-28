#!/bin/bash
# ============================================================
# HunyuanCustom — Via Appia Antica (single subject, 720P fp8)
#
# Modello richiesto: hunyuancustom_720P (fp8)
#   Download: già incluso in setup_runpod.sh
#
# Differenza rispetto a HunyuanVideo-1.5 i2v:
#   Qui --ref-image è un riferimento di IDENTITÀ (processato da
#   LLaVA), non il primo frame. La prospettiva camera è guidata
#   dal prompt, non dall'immagine — più libertà per il walkthrough
#   in prima persona.
# ============================================================
set -e

cd /workspace/HunyuanCustom
source .venv/bin/activate

# ── Edit these ───────────────────────────────────────────────
REF_IMAGE="./appia_strada.png"          # immagine di riferimento Via Appia
OUTPUT_DIR="./results/via_appia_custom"
VIDEO_SIZE_H=512                        # 512 per 24GB VRAM | 720 per 40GB+
VIDEO_SIZE_W=896                        # 896 per 24GB VRAM | 1280 per 40GB+
N_FRAMES=65                             # 65 ≈ 4s | 129 ≈ 8s
SEED=1024
# ─────────────────────────────────────────────────────────────

if [ ! -f "$REF_IMAGE" ]; then
    echo "ERROR: Immagine non trovata: $REF_IMAGE"
    echo "Carica l'immagine tramite Jupyter in /workspace/HunyuanCustom/"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

export MODEL_BASE="./models"
export DISABLE_SP=1
export PYTHONPATH=./

CKPT="${MODEL_BASE}/hunyuancustom_720P/mp_rank_00_model_states_fp8.pt"

python hymm_sp/sample_gpu_poor.py \
    --ref-image "$REF_IMAGE" \
    --pos-prompt "Realistic, High-quality, ultra-realistic cinematic. First-person perspective walking slowly forward along Via Appia Antica during the Roman Imperial period. The road is paved with large irregular basalt stones, slightly worn and uneven. On both sides of the road: monumental Roman tombs, mausoleums, temple-like structures with columns, cylindrical tombs, pyramidal roofs, statues, and carved relief decorations. Bright daylight with warm natural sunlight, soft shadows, slightly dusty atmosphere. Camera at eye level moving slowly forward, slight natural head motion, gently looking right and left at architectural details of tombs and statues. A few distant Roman figures in tunics walking along the road. Sparse vegetation, some grass, shrubs, and Roman umbrella pine trees in the background. Ultra-realistic textures, physically accurate lighting, cinematic depth of field, photorealistic, historical accuracy, immersive atmosphere, no modern elements." \
    --neg-prompt "Aerial view, bird-eye view, overexposed, low quality, deformation, bad composition, bad hands, bad teeth, bad eyes, distortion, blurring, text, subtitles, static, black border, modern elements, cars, asphalt, electricity poles, horror, violence." \
    --ckpt "$CKPT" \
    --video-size $VIDEO_SIZE_H $VIDEO_SIZE_W \
    --sample-n-frames $N_FRAMES \
    --cfg-scale 7.5 \
    --seed $SEED \
    --infer-steps 30 \
    --use-deepcache 1 \
    --flow-shift-eval-video 13.0 \
    --save-path "$OUTPUT_DIR" \
    --use-fp8

echo ""
echo "Done! Video salvato in: $OUTPUT_DIR"
