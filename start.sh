#!/bin/bash
set -e

echo "===================================="
echo "🚀 Start ComfyUI RunPod template"
echo "===================================="

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

# --- 3. Stahování modelů s viditelným progresem (opraveno pro RunPod Logs) ---
download_if_missing() {
  local dest="$1"
  local url="$2"
  if [ ! -f "$dest" ]; then
    echo "📥 Stahuji: $(basename "$dest")"
    stdbuf -oL -eL wget --progress=dot:giga -O "$dest" "$url" 2>&1 | \
      stdbuf -oL grep --line-buffered -o "[0-9]\+%" | \
      awk '{ p=$1+0; if (p >= last+10 || p == 100) { print "   ..." p "%"; last=p } }'
    if [ -f "$dest" ] && [ -s "$dest" ]; then
      echo "✅ Hotovo: $(basename "$dest") ($(du -h "$dest" | cut -f1))"
    else
      echo "⚠️ CHYBA při stahování $(basename "$dest")"
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

# --- 4. Self-healing spuštění ComfyUI ---
set +e   # od teď řešíme chyby sami, ne aby set -e ukončil skript napůl cesty

LOG_FILE="/tmp/comfyui_start.log"
MAX_ATTEMPTS=4
ATTEMPT=1

apply_known_fixes() {
  local log="$1"

  # comfy_kitchen <-> torch nekompatibilita (list[int] custom-op schema chyba)
  if grep -q "kernel_size has unsupported type list\[int\]" "$log" && grep -q "comfy_kitchen" "$log"; then
    echo "🔧 Rozpoznána chyba: comfy_kitchen <-> torch nekompatibilita. Opravuji (downgrade comfy_kitchen)..."
    pip3 install --no-cache-dir "comfy_kitchen==0.2.27"
    return $?
  fi

  # Starý driver vs. torch build (CUDA verze na nodu je nižší než torch čeká)
  if grep -qi "NVIDIA driver on your system is too old" "$log"; then
    echo "🔧 Rozpoznána chyba: starý driver vs. torch build. Přeinstalovávám torch (2.6.0, cu121)..."
    pip3 uninstall -y torch torchvision torchaudio
    pip3 install --no-cache-dir torch==2.6.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    return $?
  fi

  # Chybějící Python modul
  if grep -qi "No module named" "$log"; then
    local missing_pkg
    missing_pkg=$(grep -oP "No module named '\K[^']+" "$log" | head -n1)
    if [ -n "$missing_pkg" ]; then
      echo "🔧 Rozpoznána chyba: chybějící modul '$missing_pkg'. Instaluji..."
      pip3 install --no-cache-dir "$missing_pkg"
      return $?
    fi
    return 1
  fi

  echo "❓ Neznámá chyba, žádná automatická oprava k dispozici."
  return 1
}

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  echo "===================================="
  echo "🎬 Spouštím ComfyUI (pokus $ATTEMPT/$MAX_ATTEMPTS)..."
  echo "===================================="

  cd /opt/ComfyUI
  > "$LOG_FILE"
  stdbuf -oL -eL python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header 2>&1 | tee "$LOG_FILE" &
  PY_PID=$!

  # Sleduj prvních ~60s, jestli proces žije a port naběhl
  SUCCESS=0
  for i in $(seq 1 30); do
    if ! kill -0 $PY_PID 2>/dev/null; then
      break   # proces spadl
    fi
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8188/ 2>/dev/null | grep -q "200"; then
      SUCCESS=1
      break
    fi
    sleep 2
  done

  if [ $SUCCESS -eq 1 ]; then
    echo "✅ ComfyUI úspěšně naběhlo, přebírám popředí procesu."
    wait $PY_PID
    exit $?
  fi

  echo "❌ ComfyUI nenaběhlo / spadlo. Analyzuji log..."
  kill $PY_PID 2>/dev/null
  wait $PY_PID 2>/dev/null

  if apply_known_fixes "$LOG_FILE"; then
    echo "🔁 Oprava aplikována, zkouším znovu..."
  else
    echo "🛑 Automatická oprava se nezdařila nebo chyba není rozpoznaná."
    echo "---- Posledních 40 řádků logu: ----"
    tail -n 40 "$LOG_FILE"
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
      echo "🛑 Dosažen maximální počet pokusů ($MAX_ATTEMPTS). Nechávám pod běžet přes 'sleep infinity' pro ruční debug."
      sleep infinity
    fi
  fi

  ATTEMPT=$((ATTEMPT+1))
done
