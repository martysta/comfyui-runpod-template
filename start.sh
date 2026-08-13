#!/bin/bash

MODELS_DIR="/workspace/ComfyUI/models"
mkdir -p "$MODELS_DIR/diffusion_models" "$MODELS_DIR/text_encoders" "$MODELS_DIR/vae" "$MODELS_DIR/loras"

download_if_missing() {
  local dest="$1"
  local url="$2"
  if [ ! -f "$dest" ]; then
    echo "📥 Stahuji: $(basename "$dest")"
    if wget --progress=dot:giga -O "$dest" "$url" 2>&1 | \
       grep --line-buffered -o "[0-9]\+%" | \
       while read -r pct; do printf "\r   ...%s" "$pct"; done
    then
      echo -e "\n✅ Hotovo: $(basename "$dest") ($(du -h "$dest" | cut -f1))"
    else
      echo -e "\n⚠️ CHYBA při stahování $(basename "$dest")"
      rm -f "$dest"
    fi
  else
    echo "⏭️ Už existuje: $(basename "$dest")"
  fi
}

echo "🔍 Stahuji základní modely..."

download_if_missing "$MODELS_DIR/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

download_if_missing "$MODELS_DIR/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

download_if_missing "$MODELS_DIR/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download_if_missing "$MODELS_DIR/vae/wan_2.1_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

echo "✅ Základní modely připraveny"
echo "ℹ️  LoRA soubory (SVI v2 Pro, lightx2v 4step) doinstaluj přes LoRA Manager panel v UI po startu"

cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header &

wait
