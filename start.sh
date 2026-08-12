#!/bin/bash
set -e

MODELS_DIR="/workspace/ComfyUI/models"
mkdir -p "$MODELS_DIR/diffusion_models" \
         "$MODELS_DIR/text_encoders" \
         "$MODELS_DIR/vae" \
         "$MODELS_DIR/clip_vision"

download_if_missing() {
  local dest="$1"
  local url="$2"
  if [ ! -f "$dest" ]; then
    echo "📥 Stahuji: $(basename "$dest")"
    wget -q --show-progress -O "$dest" "$url"
    echo "✅ Hotovo: $(basename "$dest")"
  else
    echo "⏭️  Už existuje, přeskakuji: $(basename "$dest")"
  fi
}

echo "🔍 Kontrola a stahování modelů pro InfiniteTalk / Wan2.1..."

# I2V diffusion model (obraz -> video)
download_if_missing \
  "$MODELS_DIR/diffusion_models/Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors"

# InfiniteTalk model (lip-sync, single person)
download_if_missing \
  "$MODELS_DIR/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

# Text encoder
download_if_missing \
  "$MODELS_DIR/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# VAE
download_if_missing \
  "$MODELS_DIR/vae/Wan2_1_VAE_fp32.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_fp32.safetensors"

# CLIP Vision
download_if_missing \
  "$MODELS_DIR/clip_vision/clip_vision_h.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

echo "✅ Všechny modely připraveny"

# 🚀 Spuštění ComfyUI na pozadí
echo "🚀 Spouštím ComfyUI..."
cd /UI/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 &

# 🚀 Spuštění JupyterLab na pozadí
echo "🚀 Spouštím JupyterLab..."
jupyter lab --allow-root &

# Drž kontejner naživu, dokud běží procesy na pozadí
wait
