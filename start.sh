#!/bin/bash
set -e

# =========================
# 1️⃣ Vytvoření adresářů pro modely
# =========================
mkdir -p /UI/ComfyUI/models/unet \
         /UI/ComfyUI/models/clip \
         /UI/ComfyUI/models/vae \
         /UI/ComfyUI/models/controlnet \
         /UI/ComfyUI/models/upscale \
         /UI/ComfyUI/models/ultralytics/bbox

# =========================
# 2️⃣ Stažení modelů, pokud ještě nejsou
# =========================

# UNet (Flux1 Dev)
if [ ! -f /UI/ComfyUI/models/unet/flux1-dev-fp8.safetensors ]; then
    wget -O /UI/ComfyUI/models/unet/flux1-dev-fp8.safetensors \
    https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors
fi

# CLIP encodery
if [ ! -f /UI/ComfyUI/models/clip/t5xxl_fp8_e4m3fn.safetensors ]; then
    wget -O /UI/ComfyUI/models/clip/t5xxl_fp8_e4m3fn.safetensors \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
fi

if [ ! -f /UI/ComfyUI/models/clip/clip_l.safetensors ]; then
    wget -O /UI/ComfyUI/models/clip/clip_l.safetensors \
    https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors
fi

# VAE
if [ ! -f /UI/ComfyUI/models/vae/ae.safetensors ]; then
    wget -O /UI/ComfyUI/models/vae/ae.safetensors \
    https://huggingface.co/ffxvs/vae-flux/resolve/main/ae.safetensors
fi

# ControlNet (InstantID)
if [ ! -f /UI/ComfyUI/models/controlnet/diffusion_pytorch_model.safetensors ]; then
    wget -O /UI/ComfyUI/models/controlnet/diffusion_pytorch_model.safetensors \
    https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors
fi

# Upscale
if [ ! -f /UI/ComfyUI/models/upscale/4x-ClearRealityV1.pth ]; then
    wget -O /UI/ComfyUI/models/upscale/4x-ClearRealityV1.pth \
    https://huggingface.co/skbhadra/ClearRealityV1/resolve/main/4x-ClearRealityV1.pth
fi

# Face detection (YOLOv8m)
if [ ! -f /UI/ComfyUI/models/ultralytics/bbox/face_yolov8m.pt ]; then
    wget -O /UI/ComfyUI/models/ultralytics/bbox/face_yolov8m.pt \
    https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt
fi

# =========================
# 3️⃣ Spuštění JupyterLab
# =========================
jupyter lab --allow-root &

# =========================
# 4️⃣ Spuštění ComfyUI
# =========================
python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188
