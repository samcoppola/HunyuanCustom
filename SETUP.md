# HunyuanCustom — RunPod Setup Guide

## Differenza rispetto a HunyuanVideo-1.5 i2v

| Aspetto | HunyuanVideo-1.5 i2v | HunyuanCustom |
|---|---|---|
| Uso dell'immagine | Primo frame del video — prospettiva bloccata sull'immagine | Riferimento di identità soggetto (LLaVA) — prospettiva libera |
| Controllo camera | Dipende dal punto di vista dell'immagine | Guidato dal prompt testuale |
| Caso d'uso | Continuazione naturale di un'immagine | Soggetto specifico in scene diverse / camera motion dal testo |
| Prompt rewriting | Sì (Claude, opzionale) | No |

> Per generare un walkthrough in prima persona lungo la Via Appia da un'immagine **laterale/panoramica**, HunyuanCustom è l'approccio giusto: l'immagine viene usata come riferimento visivo (architettura, stile, texture) ma la prospettiva camera segue il prompt.

---

## Prerequisiti

Nessun token obbligatorio. HuggingFace token opzionale se vuoi evitare rate-limiting:

```bash
export HF_TOKEN="hf_..."    # opzionale
```

---

## Caso 1 — Nuovo pod, workspace esistente

Il Network Volume ha già repo, venv e modelli. Basta attivare il venv:

```bash
cd /workspace/HunyuanCustom
git pull
source .venv/bin/activate
```

Poi lancia lo script di generazione.

---

## Caso 2 — Nuovo workspace (da zero)

Il flusso ottimale usa **due pod separati**: uno CPU economico per scaricare i modelli, uno GPU per installare le dipendenze e generare.

> **Perché separare?** Il venv va creato sul pod GPU — così torch viene installato con la versione CUDA corretta del sistema. Su un pod CPU si installerebbe torch senza CUDA e il modello non userebbe la GPU.

### Step 1 — Pod CPU: clone repo + download modelli (~38 GB)

```bash
export HF_TOKEN="hf_..."   # opzionale
bash download_only.sh
```

Stoppa il pod CPU quando finisce.

### Step 2 — Pod GPU: venv + dipendenze

Avvia un pod GPU con lo **stesso Network Volume**, poi:

```bash
cd /workspace/HunyuanCustom
bash setup_gpu.sh
```

`setup_gpu.sh` rileva automaticamente la versione CUDA e installa torch corrispondente, poi il resto delle dipendenze.

> **Flash-attention** (opzionale, migliora la velocità su A100/H100, compila in 30+ min):
> ```bash
> INSTALL_FLASH_ATTN=true bash setup_gpu.sh
> ```

### Step 3 — Carica la tua immagine

Carica l'immagine tramite Jupyter in `/workspace/HunyuanCustom/`.

### Download modelli aggiuntivi (opzionale)

```bash
source .venv/bin/activate

python download_models.py base audio-720p      # audio-driven (~38 GB)
python download_models.py base editing-720p    # video editing (~38 GB)
```

---

## Modelli

| Directory | Dimensione | Uso | Note |
|---|---|---|---|
| `hunyuancustom_720P` (fp8) | ~20 GB | image customization | **sempre richiesto** |
| `vae_3d` | ~1 GB | tutti | encoder/decoder video |
| `llava-llama-3-8b-v1_1` | ~15 GB | tutti | comprensione immagine |
| `openai_clip-vit-large-patch14` | ~1.7 GB | tutti | embedding visivo |
| `hunyuancustom_audio_720P` | ~20 GB | audio-driven | skippato di default |
| `hunyuancustom_editing_720P` | ~20 GB | video editing | skippato di default |
| `DWPose` | ~300 MB | video umani | skippato di default |
| `whisper-tiny` | ~150 MB | audio-driven | skippato di default |

**Spazio disco minimo:** ~38 GB (solo image customization con fp8)

**Liberare spazio** (se scaricato tutto):
```bash
rm -rf models/hunyuancustom_audio_720P
rm -rf models/hunyuancustom_editing_720P
rm -rf models/whisper-tiny
```

---

## VRAM

| Configurazione | VRAM | Risoluzione | Note |
|---|---|---|---|
| `DISABLE_SP=1` + `--use-fp8` | ~24 GB | 512×896 | RTX 3090/4090, più veloce |
| `CPU_OFFLOAD=1` + `--use-fp8` + `--cpu-offload` | ~8 GB | 720×1280 | molto lento |
| Multi-GPU (`torchrun`) | 80 GB (8×GPU) | 720×1280 | qualità massima |

---

## Generazione

Ogni script ha le variabili editabili in cima al file (`REF_IMAGE`, `POS_PROMPT`, `N_FRAMES`, ecc.).

| Script | Task | Modelli richiesti | VRAM |
|---|---|---|---|
| `bash run_image_512p.sh` | Image customization 512×896 | hunyuancustom_720P (fp8) + base | ~24 GB |
| `bash run_image_720p.sh` | Image customization 720×1280 | hunyuancustom_720P (fp8) + base | ~40 GB |
| `bash run_audio_512p.sh` | Audio-driven 512×896 | hunyuancustom_audio_720P + base + whisper | ~24 GB |
| `bash run_audio_720p.sh` | Audio-driven 720×1280 | hunyuancustom_audio_720P + base + whisper | ~40 GB |
| `bash run_editing_720p.sh` | Video editing / object replacement | hunyuancustom_editing_720P + base | ~40 GB |
| `bash run_via_appia_custom.sh` | Via Appia (preconfigurato) | hunyuancustom_720P (fp8) + base | ~24 GB |

> "Base" = vae_3d + llava-llama-3-8b-v1_1 + openai_clip (sempre richiesti, inclusi nel setup default).

### Via Appia (script preconfigurato)

```bash
cd /workspace/HunyuanCustom
bash run_via_appia_custom.sh
```

> Modifica le variabili in cima allo script (`REF_IMAGE`, `VIDEO_SIZE_H/W`, `N_FRAMES`).

### Comando manuale (single GPU)

```bash
cd /workspace/HunyuanCustom
source .venv/bin/activate

export MODEL_BASE="./models"
export DISABLE_SP=1
export PYTHONPATH=./

python hymm_sp/sample_gpu_poor.py \
    --ref-image './tua_immagine.png' \
    --pos-prompt "Realistic, High-quality. [descrizione scena e movimento camera]" \
    --neg-prompt "Aerial view, overexposed, low quality, deformation, distortion, blurring, text, subtitles, static, black border." \
    --ckpt models/hunyuancustom_720P/mp_rank_00_model_states_fp8.pt \
    --video-size 512 896 \
    --sample-n-frames 65 \
    --cfg-scale 7.5 \
    --seed 1024 \
    --infer-steps 30 \
    --use-deepcache 1 \
    --flow-shift-eval-video 13.0 \
    --save-path ./results/output \
    --use-fp8
```

### Parametri utili

| Parametro | Valori | Note |
|---|---|---|
| `--video-size` | `512 896` / `720 1280` | 512×896 per 24GB, 720×1280 per 40GB+ |
| `--sample-n-frames` | 65 / 129 | 65 ≈ 4s, 129 ≈ 8s |
| `--cfg-scale` | 7.5 | guidance scale, aumenta per più aderenza al prompt |
| `--infer-steps` | 30 | passi di inferenza, aumenta per qualità (più lento) |
| `--use-deepcache 1` | — | ottimizzazione velocità, disabilita se artefatti |
| `--use-fp8` | — | riduce VRAM, necessario su GPU consumer |
| `--cpu-offload` | — | offload CPU, usa con `CPU_OFFLOAD=1`, molto lento |

I video vengono salvati in `./results/`.
