#!/bin/bash
# ============================================================
# AUDIO-DRIVEN CUSTOMIZATION — 720×1280 (single GPU, ~40 GB VRAM)
# Required models: hunyuancustom_audio_720P (fp8) + vae_3d + llava + clip + whisper
#   Per scaricare: rimuovi "models/hunyuancustom_audio_720P/*" e
#                  "models/whisper-tiny/*" da ignore_patterns in setup_runpod.sh
#                  e rilancia il setup.
# ============================================================
set -e

cd /workspace/HunyuanCustom
source .venv/bin/activate

# ── Edit these ───────────────────────────────────────────────
REF_IMAGE="./assets/images/seg_man_01.png"     # immagine soggetto (deve essere persona)
INPUT_AUDIO="./assets/audios/milk_man.mp3"     # file audio .mp3 / .wav
OUTPUT_DIR="./results/audio_720p"
POS_PROMPT="Realistic, High-quality. In the study, a man sits at a table featuring a bottle of milk while delivering a product presentation."
NEG_PROMPT="Two people, two persons, aerial view, aerial view, overexposed, low quality, deformation, a poor composition, bad hands, bad teeth, bad eyes, bad limbs, distortion, blurring, text, subtitles, static, picture, black border."
AUDIO_STRENGTH=0.8   # 0.0–1.0, controlla quanto l'audio guida il movimento
N_FRAMES=129         # deve corrispondere alla durata dell'audio
SEED=1024
# ─────────────────────────────────────────────────────────────

if [ ! -f "$INPUT_AUDIO" ]; then
    echo "ERROR: File audio non trovato: $INPUT_AUDIO"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

export MODEL_BASE="./models"
export DISABLE_SP=1
export PYTHONPATH=./

python hymm_sp/sample_gpu_poor.py \
    --audio-condition \
    --ref-image "$REF_IMAGE" \
    --input-audio "$INPUT_AUDIO" \
    --audio-strength $AUDIO_STRENGTH \
    --pos-prompt "$POS_PROMPT" \
    --neg-prompt "$NEG_PROMPT" \
    --ckpt ${MODEL_BASE}/hunyuancustom_audio_720P/mp_rank_00_model_states_fp8.pt \
    --video-size 720 1280 \
    --sample-n-frames $N_FRAMES \
    --cfg-scale 7.5 \
    --seed $SEED \
    --infer-steps 30 \
    --use-deepcache 1 \
    --flow-shift-eval-video 13.0 \
    --save-path "$OUTPUT_DIR" \
    --use-fp8

echo "Done! Video salvato in: $OUTPUT_DIR"
