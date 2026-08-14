#!/bin/bash
set -e

# --- 1. Připrav strukturu na persistentním Network Volume ---
MODELS_DIR="/workspace/models"
mkdir -p "$MODELS_DIR/diffusion_models" "$MODELS_DIR/text_encoders" "$MODELS_DIR/vae" "$MODELS_DIR/loras"
mkdir -p /workspace/output /workspace/input /workspace/user

# --- 2. Symlinky z /opt/ComfyUI do volume (jen když ještě nejsou) ---
[ -L /opt/ComfyUI/models ] || (rm -rf /opt/ComfyUI/models && ln -s /workspace/models /opt/ComfyUI/models)
[ -L /opt/ComfyUI/output ] || (rm -rf /opt/ComfyUI/output && ln -s /workspace/output /opt/ComfyUI/output)
[ -L /opt/ComfyUI/input ] || (rm -rf /opt/ComfyUI/input && ln -s /workspace/input /opt/ComfyUI/input)
[ -L /opt/ComfyUI/user ] || (rm -rf /opt/ComfyUI/user && ln -s /workspace/user /opt/ComfyUI/user)

# --- 3. Stahování modelů s viditelným progresem ---
download_if_missing() {
  local dest="$1"
  local url="$2"
  if [ ! -f "$dest" ]; then
    echo "📥 Stahuji: $(basename "$dest")"
    wget --progress=dot:giga -O "$dest" "$url" 2>&1 | \
      grep --line-buffered -o "[0-9]\+%" | \
      while read -r pct; do printf "\r   ...%s" "$pct"; done
    if [ -f "$dest" ] && [ -s "$dest" ]; then
      echo -e "\n✅ Hotovo: $(basename "$dest") ($(du -h "$dest" | cut -f1))"
    else
      echo -e "\n⚠️ CHYBA při stahování $(basename "$dest")"
      rm -f "$dest"
      exit 1
    fi
  else
    echo "⏭️ Už existuje: $(basename "$dest") ($(du -h "$dest" | cut -f1))"
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

# --- 4. Spusť ComfyUI z /opt (image), ne z /workspace ---
cd /opt/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
