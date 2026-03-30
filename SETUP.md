# HunyuanCustom — RunPod Setup Guide

## Cos'è HunyuanCustom (vs HunyuanVideo-1.5 i2v)

| Aspetto | HunyuanVideo-1.5 i2v | HunyuanCustom |
|---|---|---|
| Uso dell'immagine | Primo frame del video — prospettiva bloccata sull'immagine | Riferimento identità soggetto (LLaVA) — prospettiva libera |
| Controllo camera | Dipende dal punto di vista dell'immagine | Guidato dal prompt testuale |
| Caso d'uso | Continuazione naturale di un'immagine | Soggetto in scene diverse, camera motion da testo |

> **Via Appia:** con HunyuanVideo i2v l'immagine laterale blocca la prospettiva — il video parte dal punto di vista della foto. Con HunyuanCustom l'immagine è solo un riferimento visivo (stile, architettura, texture) e la prospettiva camera segue il prompt: utile per generare il walkthrough in prima persona.

---

## Token e risorse RunPod

**Token:** nessuno obbligatorio. HF_TOKEN opzionale per evitare rate-limiting HuggingFace.

```bash
export HF_TOKEN="hf_..."    # opzionale
```

**Risorse consigliate:**

| Risorsa | Valore | Note |
|---|---|---|
| Network Volume (disco) | **75 GB** | per un modello alla volta |
| GPU per generazione | **A100 40GB** | fp8 a 720×1280 |
| GPU alternativa | RTX 4090 (24GB) | fp8 a 512×896, più lento |

---

## Caso 1 — Pod già configurato (workspace esistente)

Il Network Volume ha già repo, venv e modelli. Basta attivare il venv:

```bash
cd /workspace/HunyuanCustom
git pull
source .venv/bin/activate
```

Poi lancia lo script di generazione desiderato.

---

## Caso 2 — Nuovo workspace (da zero)

Il flusso ottimale usa due pod separati: uno CPU economico per scaricare i modelli, uno GPU per installare le dipendenze e generare.

> **Perché separare?** Il venv va creato sul pod GPU — così torch viene installato con la versione CUDA corretta. Se creato su un pod CPU, torch non avrebbe supporto CUDA e il modello non userebbe la GPU.

### Step 1 — Pod CPU: clone repo + download modelli

Crea un pod CPU con il Network Volume montato su `/workspace`, poi:

```bash
export HF_TOKEN="hf_..."   # opzionale
bash <(curl -s https://raw.githubusercontent.com/samcoppola/HunyuanCustom/main/download_only.sh)
```

Oppure se il repo è già clonato:

```bash
cd /workspace/HunyuanCustom
bash download_only.sh
```

**Stoppa il pod CPU** quando il download è completato.

#### Scegliere cosa scaricare

`download_only.sh` accetta i nomi dei modelli come argomenti (default: `base image-720p`):

```bash
bash download_only.sh base image-720p      # Via Appia / image customization (~38 GB) ← default
bash download_only.sh base audio-720p      # audio-driven (~38 GB)
bash download_only.sh base editing-720p    # video editing / object replacement (~38 GB)
bash download_only.sh base image-720p dwpose  # image + pose estimation (~38.3 GB)
```

Oppure usa `download_models.py` direttamente per più controllo:

```bash
python download_models.py base             # solo base (~18 GB)
python download_models.py image-720p       # aggiunge solo il modello immagine (~20 GB)
python download_models.py audio-720p       # aggiunge solo il modello audio (~20 GB)
python download_models.py editing-720p     # aggiunge solo il modello editing (~20 GB)
python download_models.py dwpose           # aggiunge DWPose (~0.3 GB)
```

### Step 2 — Pod GPU: venv + dipendenze

Avvia un pod GPU con lo **stesso Network Volume**, poi:

```bash
cd /workspace/HunyuanCustom
bash setup_gpu.sh
```

`setup_gpu.sh` rileva automaticamente la versione CUDA (11.8 / 12.1 / 12.4) e installa torch con il wheel corretto, poi il resto delle dipendenze.

> **Flash-attention** (opzionale, migliora la velocità su A100/H100, compilazione ~30 min):
> ```bash
> INSTALL_FLASH_ATTN=true bash setup_gpu.sh
> ```

### Step 3 — Carica la tua immagine

Carica l'immagine di riferimento (es. `appia_strada.png`) tramite **Jupyter** in `/workspace/HunyuanCustom/`.

---

## Caso 3 — Venv già creato su pod CPU (fix torch CUDA)

Se il venv è stato creato su un pod CPU, torch non ha supporto CUDA. Sul pod GPU:

```bash
cd /workspace/HunyuanCustom
source .venv/bin/activate

# Reinstalla torch con CUDA (sostituisce la versione CPU):
pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124 --force-reinstall

# Verifica:
python -c "import torch; print(torch.cuda.is_available())"
# deve stampare: True
```

Usa `cu118` al posto di `cu124` se il pod ha CUDA 11.8.

---

## Modelli disponibili

| Modello | Dimensione | Uso | Scaricato di default |
|---|---|---|---|
| `base` (vae_3d + llava + clip) | ~18 GB | tutti — sempre richiesto | sì |
| `image-720p` (hunyuancustom_720P fp8) | ~20 GB | image/subject customization | sì |
| `audio-720p` (hunyuancustom_audio_720P fp8 + whisper) | ~20 GB | audio-driven (lipsync) | no |
| `editing-720p` (hunyuancustom_editing_720P fp8) | ~20 GB | video editing / object replacement | no |
| `dwpose` | ~0.3 GB | miglioramento pose per video umani | no |

**Liberare spazio** (se hai scaricato più modelli):

```bash
rm -rf models/hunyuancustom_audio_720P
rm -rf models/hunyuancustom_editing_720P
rm -rf models/whisper-tiny
```

---

## VRAM richiesta

| Configurazione | VRAM | Risoluzione | Velocità |
|---|---|---|---|
| fp8 + `DISABLE_SP=1` | ~24 GB | 512×896 | veloce |
| fp8 + `DISABLE_SP=1` | ~40 GB | 720×1280 | media |
| fp8 + `CPU_OFFLOAD=1` + `--cpu-offload` | ~8 GB | 720×1280 | molto lenta |

---

## Generazione

Ogni script ha le variabili editabili in cima (`REF_IMAGE`, `POS_PROMPT`, `N_FRAMES`, ecc.).

| Script | Task | Modello richiesto | VRAM |
|---|---|---|---|
| `bash run_image_512p.sh` | Image customization 512×896 | image-720p + base | ~24 GB |
| `bash run_image_720p.sh` | Image customization 720×1280 | image-720p + base | ~40 GB |
| `bash run_audio_512p.sh` | Audio-driven 512×896 | audio-720p + base | ~24 GB |
| `bash run_audio_720p.sh` | Audio-driven 720×1280 | audio-720p + base | ~40 GB |
| `bash run_editing_720p.sh` | Video editing / object replacement | editing-720p + base | ~40 GB |
| `bash run_via_appia_custom.sh` | Via Appia Antica (preconfigurato) | image-720p + base | ~24 GB |

### Via Appia — script preconfigurato

Lo script `run_via_appia_custom.sh` ha già il prompt completo e usa `appia_strada.png` come immagine di riferimento. Modifica in cima allo script se necessario:

```bash
cd /workspace/HunyuanCustom
source .venv/bin/activate
bash run_via_appia_custom.sh
```

Output in `./results/via_appia_custom/`.

### Parametri utili

| Parametro | Valori | Note |
|---|---|---|
| `--video-size` | `512 896` / `720 1280` | 512×896 per 24 GB, 720×1280 per 40 GB+ |
| `--sample-n-frames` | 65 / 129 | 65 ≈ 4s, 129 ≈ 8s |
| `--cfg-scale` | 7.5 | guidance scale — aumenta per più aderenza al prompt |
| `--infer-steps` | 30 | passi di inferenza — aumenta per qualità (più lento) |
| `--use-deepcache 1` | — | ottimizzazione velocità — disabilita se compaiono artefatti |
| `--use-fp8` | — | riduce VRAM — necessario su GPU consumer |
| `--cpu-offload` | — | offload su CPU — usa con `CPU_OFFLOAD=1`, molto lento |
| `--seed` | qualsiasi intero | fissa il seed per risultati riproducibili |
