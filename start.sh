#!/bin/bash
set -e

echo "===================================="
echo "🚀 Start ComfyUI RunPod template"
echo "===================================="

# --- 0. Zajisti kompatibilní PyTorch podle CUDA driveru na tomto nodu ---
echo "🔧 Kontroluji kompatibilitu CUDA driveru s PyTorch..."

DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
CUDA_MAX=$(nvidia-smi | grep -oP "CUDA Version: \K[0-9]+\.[0-9]+" | head -n1)
echo "   Driver: $DRIVER_VERSION | Max podporovaná CUDA na tomto nodu: $CUDA_MAX"

TORCH_OK=$(python3 -c "
import torch
try:
    x = torch.zeros(1).cuda()
    print('OK')
except Exception:
    print('FAIL')
" 2>/dev/null)

if [ "$TORCH_OK" != "OK" ]; then
  echo "⚠️  PyTorch nefunguje s tímto driverem, přeinstalovávám na CUDA 12.1 build (širší kompatibilita)..."
  pip3 uninstall -y torch torchvision torchaudio
  pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
  echo "✅ PyTorch přeinstalován"
else
  echo "✅ PyTorch je s tímto driverem kompatibilní"
fi

# --- 1. Připrav strukturu na persistentním Network Volume ---
echo "📁 Připravuji strukturu na /workspace..."
MODELS_DIR="/workspace/models"
mkdir -p "$MODELS_DIR/diffusion_models" "$MODELS_DIR/text_encoders" "$MODELS_DIR/vae" "$MODELS_DIR/loras"
mkdir -p /workspace/output /workspace/input /workspace/user

# --- 2. Symlinky z /opt/ComfyUI do volume (jen když ještě nejsou) ---
[ -L /opt/ComfyUI/models ] || (rm -rf /opt/ComfyUI/models && ln -s /workspace/models /opt/ComfyUI/models)
[ -L /opt/ComfyUI/output ] || (rm -rf /opt/ComfyUI/output && ln -s /workspace/output /opt/ComfyUI/output)
[ -L /opt/ComfyUI/input ] || (rm -rf /opt/ComfyUI/input && ln -s /workspace/input /opt/ComfyUI/input)
[ -L /opt/ComfyUI/user ] || (rm -rf /opt/ComfyUI/user && ln -s /workspace/user /opt/ComfyUI/user)
echo "✅ Symlinky OK"

# --- 2b. Vynuť angličtinu jako výchozí jazyk (jen když nastavení ještě neexistuje) ---
SETTINGS_FILE="/workspace/user/default/comfy.settings.json"
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "🌐 Nastavuji výchozí jazyk na angličtinu..."
  echo '{"Comfy.Locale": "en"}' > "$SETTINGS_FILE"
else
  echo "⏭️ Nastavení uživatele už existuje, jazyk neměním"
fi

# --- 2c. Zkopíruj všechny WanVideoWrapper example workflows (jednou, do podsložky) ---
EXAMPLES_SRC="/opt/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/example_workflows"
EXAMPLES_DST="/workspace/user/default/workflows/wanvideo_examples"
if [ -d "$EXAMPLES_SRC" ] && [ ! -d "$EXAMPLES_DST" ]; then
  echo "📋 Kopíruji všechny WanVideoWrapper example workflows..."
  mkdir -p "$EXAMPLES_DST"
  cp "$EXAMPLES_SRC"/*.json "$EXAMPLES_DST"/ 2>/dev/null
  echo "✅ Zkopírováno $(ls "$EXAMPLES_DST" | wc -l) workflow souborů"
else
  echo "⏭️ Example workflows už zkopírované (nebo zdroj neexistuje), přeskakuji"
fi

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
download_if_missing "$MODELS_DIR/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

echo "✅ Základní modely připraveny (včetně InfiniteTalk Single)"
echo "ℹ️  LoRA soubory (SVI v2 Pro, lightx2v 4step) doinstaluj přes LoRA Manager panel v UI po startu"

# --- 4. Spusť ComfyUI z /opt (image), ne z /workspace ---
echo "===================================="
echo "🎬 Spouštím ComfyUI..."
echo "===================================="
cd /opt/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
