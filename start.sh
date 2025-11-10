#!/bin/bash
set -e

# =========================
# 1️⃣ Vytvoření adresářů pro modely
# =========================
mkdir -p /workspace/ComfyUI/models/unet \
         /workspace/ComfyUI/models/clip \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/controlnet \
         /workspace/ComfyUI/models/upscale \
         /workspace/ComfyUI/models/ultralytics/bbox

# =========================
# 2️⃣ Stažení modelů, pokud ještě nejsou
# =========================

download() {
    local target="$1"
    local url="$2"
    if [ ! -f "$target" ]; then
        echo "📥 Stahuji $(basename "$target")..."
        wget --show-progress --progress=bar:force:noscroll -O "$target" "$url"
        echo "✅ Hotovo: $(basename "$target")"
    else
        echo "✅ Už existuje: $(basename "$target")"
    fi
}

# UNet (Flux1 Dev)
download /workspace/ComfyUI/models/unet/flux1-dev-fp8.safetensors \
         https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors

# CLIP encodery
download /workspace/ComfyUI/models/clip/t5xxl_fp8_e4m3fn.safetensors \
         https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors

download /workspace/ComfyUI/models/clip/clip_l.safetensors \
         https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors

# VAE
download /workspace/ComfyUI/models/vae/ae.safetensors \
         https://huggingface.co/receptektas/black-forest-labs-ae_safetensors/resolve/main/ae.safetensors

# ControlNet (InstantID)
download /workspace/ComfyUI/models/controlnet/diffusion_pytorch_model.safetensors \
         https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors

download /workspace/ComfyUI/models/controlnet/flux_shakker_labs_union_pro-fp8_e4m3fn.safetensors \
         https://huggingface.co/Kijai/flux-fp8/resolve/main/flux_shakker_labs_union_pro-fp8_e4m3fn.safetensors

# Upscale
download /workspace/ComfyUI/models/upscale_models/4x-ClearRealityV1.pth \
         https://huggingface.co/skbhadra/ClearRealityV1/resolve/main/4x-ClearRealityV1.pth

# Face detection (YOLOv8m)
download /workspace/ComfyUI/models/ultralytics/bbox/face_yolov8m.pt \
         https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt

# =========================
# 3️⃣ Spuštění JupyterLab
# =========================
echo "🚀 Spouštím JupyterLab..."
jupyter lab --allow-root --notebook-dir=/workspace &

# =========================
# 4️⃣ Spuštění ComfyUI
# =========================
echo "🚀 Spouštím ComfyUI..."
python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188
