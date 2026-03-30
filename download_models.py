#!/usr/bin/env python3
"""
HunyuanCustom — Model Download Manager

Usage:
    python download_models.py <model> [<model> ...]

Available models:
    base            vae_3d + llava-llama-3-8b + clip (~18 GB) — sempre richiesto
    image-720p      hunyuancustom_720P fp8 (~20 GB)  — image/subject customization
    audio-720p      hunyuancustom_audio_720P fp8 + whisper-tiny (~20 GB)
    editing-720p    hunyuancustom_editing_720P fp8 (~20 GB)  — object replacement in video
    dwpose          DWPose pose estimator (~0.3 GB)  — solo per video con persone

Combinazioni tipiche:
    python download_models.py base image-720p          # Via Appia / image customization (~38 GB)
    python download_models.py base audio-720p          # audio-driven avatar (~38 GB)
    python download_models.py base editing-720p        # video editing (~38 GB)
    python download_models.py base image-720p dwpose   # image + pose (~38.3 GB)

HF_TOKEN: non obbligatorio (repo pubblico), ma consigliato per evitare rate-limiting.
    export HF_TOKEN="hf_..."
"""
import os
import sys

os.environ["HF_HUB_DISABLE_XET"] = "1"
# hf_transfer accelera i download ma richiede il pacchetto installato.
# Lo disabilitiamo qui e lo gestiamo esplicitamente sotto.
os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "0"
from huggingface_hub import snapshot_download, hf_hub_download

MODELS_DIR = "./models"
HF_REPO = "tencent/HunyuanCustom"
HF_TOKEN = os.environ.get("HF_TOKEN")

MODELS = {
    "base": {
        "desc": "vae_3d + llava-llama-3-8b-v1_1 + openai_clip (~18 GB) — sempre richiesto",
        "downloads": [
            {
                "patterns": [
                    "models/vae_3d/**",
                    "models/llava-llama-3-8b-v1_1/**",
                    "models/openai_clip-vit-large-patch14/**",
                ],
                "check_path": f"{MODELS_DIR}/llava-llama-3-8b-v1_1",
            }
        ],
    },
    "image-720p": {
        "desc": "hunyuancustom_720P fp8 (~20 GB) — image/subject customization",
        "downloads": [
            {
                "patterns": [
                    "models/hunyuancustom_720P/mp_rank_00_model_states_fp8.pt",
                    "models/hunyuancustom_720P/mp_rank_00_model_states_fp8_map.pt",
                ],
                "check_path": f"{MODELS_DIR}/hunyuancustom_720P/mp_rank_00_model_states_fp8.pt",
            }
        ],
    },
    "audio-720p": {
        "desc": "hunyuancustom_audio_720P fp8 + whisper-tiny (~20 GB) — audio-driven customization",
        "downloads": [
            {
                "patterns": [
                    "models/hunyuancustom_audio_720P/mp_rank_00_model_states_fp8.pt",
                    "models/hunyuancustom_audio_720P/mp_rank_00_model_states_fp8_map.pt",
                    "models/whisper-tiny/**",
                ],
                "check_path": f"{MODELS_DIR}/hunyuancustom_audio_720P/mp_rank_00_model_states_fp8.pt",
            }
        ],
    },
    "editing-720p": {
        "desc": "hunyuancustom_editing_720P fp8 (~20 GB) — video editing / object replacement",
        "downloads": [
            {
                "patterns": [
                    "models/hunyuancustom_editing_720P/mp_rank_00_model_states_fp8.pt",
                    "models/hunyuancustom_editing_720P/mp_rank_00_model_states_fp8_map.pt",
                ],
                "check_path": f"{MODELS_DIR}/hunyuancustom_editing_720P/mp_rank_00_model_states_fp8.pt",
            }
        ],
    },
    "dwpose": {
        "desc": "DWPose pose estimator (~0.3 GB) — opzionale, per video con persone",
        "downloads": [
            {
                "repo": "yzd-v/DWPose",
                "patterns": ["yolox_l.onnx", "dw-ll_ucoco_384.onnx"],
                "check_path": f"{MODELS_DIR}/DWPose/yolox_l.onnx",
                "local_dir": f"{MODELS_DIR}/DWPose",
            }
        ],
    },
}


def is_downloaded(path):
    if os.path.isfile(path):
        return os.path.getsize(path) > 1024 * 1024  # > 1 MB
    if os.path.isdir(path):
        return len(os.listdir(path)) > 0
    return False


def download_model(name):
    if name not in MODELS:
        print(f"ERROR: Modello sconosciuto '{name}'.")
        print(f"Disponibili: {', '.join(MODELS.keys())}")
        sys.exit(1)

    model = MODELS[name]
    print(f"\n{'='*60}")
    print(f"  {name}  —  {model['desc']}")
    print(f"{'='*60}")

    for dl in model["downloads"]:
        if is_downloaded(dl["check_path"]):
            print(f"  Già presente ({dl['check_path']}) — skip.")
            continue

        repo = dl.get("repo", HF_REPO)
        local_dir = dl.get("local_dir", "/workspace/HunyuanCustom")
        print(f"  Downloading from {repo} ...")
        os.makedirs(local_dir, exist_ok=True)
        snapshot_download(
            repo_id=repo,
            local_dir=local_dir,
            allow_patterns=dl["patterns"],
            token=HF_TOKEN,
            local_dir_use_symlinks=False,
        )
        print(f"  Done.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    for model_name in sys.argv[1:]:
        download_model(model_name)

    print(f"\nTutti i modelli richiesti scaricati in {MODELS_DIR}/")
