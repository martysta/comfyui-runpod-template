#!/bin/bash
set -e

echo "===================================="
echo "🚀 Start ComfyUI RunPod template"
echo "===================================="

# --- 0. Kontrola driveru: torch v image je postavený na CUDA 12.6 → potřebuje driver 525+ ---
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
DRIVER_MAJOR=${DRIVER_VERSION%%.*}
if [ -n "$DRIVER_MAJOR" ] && [ "$DRIVER_MAJOR" -lt 525 ] 2>/dev/null; then
  echo "🛑 NVIDIA driver $DRIVER_VERSION je příliš starý (potřeba 525+ kvůli CUDA 12.6)."
  echo "   Smaž tento pod a vytvoř nový s filtrem CUDA verze 12.4 nebo vyšší."
  sleep infinity
fi
echo "✅ NVIDIA driver: ${DRIVER_VERSION:-neznámý}"

# --- 0b. Počkej na síť: na RunPodu DNS při startu kontejneru pár sekund nefunguje ---
for i in $(seq 1 60); do
  if getent hosts huggingface.co >/dev/null 2>&1; then
    echo "✅ Síť připravena (po $((i*2-2)) s)"
    break
  fi
  echo "⏳ Čekám na síť ($i/60)..."
  sleep 2
done

# --- 1. Připrav strukturu na persistentním Network Volume ---
echo "📁 Připravuji strukturu na /workspace..."
MODELS_DIR="/workspace/models"
mkdir -p "$MODELS_DIR/diffusion_models" "$MODELS_DIR/text_encoders" "$MODELS_DIR/vae" "$MODELS_DIR/loras" \
         "$MODELS_DIR/model_patches" "$MODELS_DIR/audio_encoders"
mkdir -p /workspace/output /workspace/input /workspace/user

# --- 2. Symlinky z /opt/ComfyUI do volume (jen když ještě nejsou) ---
[ -L /opt/ComfyUI/models ] || (rm -rf /opt/ComfyUI/models && ln -s /workspace/models /opt/ComfyUI/models)
[ -L /opt/ComfyUI/output ] || (rm -rf /opt/ComfyUI/output && ln -s /workspace/output /opt/ComfyUI/output)
[ -L /opt/ComfyUI/input ] || (rm -rf /opt/ComfyUI/input && ln -s /workspace/input /opt/ComfyUI/input)
[ -L /opt/ComfyUI/user ] || (rm -rf /opt/ComfyUI/user && ln -s /workspace/user /opt/ComfyUI/user)
echo "✅ Symlinky OK"

# --- 2a. ai-toolkit: data na volume, fronta tréninků a volitelné webové rozhraní ---
AITK=/opt/ai-toolkit
AITK_DATA=/workspace/ai-toolkit
export HF_HOME=/workspace/hf_cache   # základní modely pro trénink (desítky GB) přežijí restart
mkdir -p "$AITK_DATA/datasets" "$AITK_DATA/data" "$HF_HOME" \
         /workspace/input/aitk_jobs /workspace/output/aitk /workspace/output/aitk_logs
for d in datasets data; do
  [ -L "$AITK/$d" ] || (rm -rf "$AITK/$d" && ln -s "$AITK_DATA/$d" "$AITK/$d")
done
[ -L "$AITK/output" ] || (rm -rf "$AITK/output" && ln -s /workspace/output/aitk "$AITK/output")
touch "$AITK_DATA/aitk_db.db"
[ -L "$AITK/aitk_db.db" ] || (rm -f "$AITK/aitk_db.db" && ln -s "$AITK_DATA/aitk_db.db" "$AITK/aitk_db.db")
# natrénované LoRA uvidí ComfyUI v seznamu LoRA pod aitk/...
[ -L "$MODELS_DIR/loras/aitk" ] || ln -s /workspace/output/aitk "$MODELS_DIR/loras/aitk"

# Fronta: konfigurace *.yaml nahraná do /workspace/input/aitk_jobs (např. přes ComfyUI /upload/image)
# se spustí jedna po druhé; log jde do /workspace/output/aitk_logs, kde je čitelný přes ComfyUI /view.
aitk_queue() {
  set +e   # chyba jednoho tréninku nesmí ukončit frontu (start.sh běží se set -e)
  while true; do
    for cfg in /workspace/input/aitk_jobs/*.yaml; do
      [ -e "$cfg" ] || continue
      name=$(basename "$cfg" .yaml)
      [ -e "/workspace/output/aitk_logs/$name.log" ] && continue
      echo "🏋️ ai-toolkit: spouštím trénink $name"
      (cd "$AITK" && HF_HOME="$HF_HOME" venv/bin/python run.py "$cfg") \
        > "/workspace/output/aitk_logs/$name.log" 2>&1
      echo "exit code: $?" >> "/workspace/output/aitk_logs/$name.log"
      echo "🏁 ai-toolkit: trénink $name skončil"
    done
    sleep 15
  done
}
aitk_queue &

# Webové rozhraní na portu 8675 jen s heslem (AI_TOOLKIT_AUTH v proměnných prostředí podu)
if [ -n "$AI_TOOLKIT_AUTH" ]; then
  echo "🌐 Spouštím ai-toolkit UI na portu 8675"
  (cd "$AITK/ui" && npx prisma db push --skip-generate >/dev/null 2>&1; HF_HOME="$HF_HOME" npm run start) \
    > /tmp/aitk_ui.log 2>&1 &
else
  echo "⏭️ ai-toolkit UI se nespouští (není nastavené heslo AI_TOOLKIT_AUTH)"
fi

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
    local wlog="/tmp/wget_$(basename "$dest").log"
    stdbuf -oL -eL wget --tries=5 --waitretry=5 --retry-connrefused --progress=dot:giga \
      -O "$dest.part" "$url" 2>&1 | tee "$wlog" | \
      stdbuf -oL grep --line-buffered -o "[0-9]\+%" | \
      awk '{ p=$1+0; if (p >= last+10 || p == 100) { print "   ..." p "%"; last=p } }'
    local wget_status=${PIPESTATUS[0]}
    if [ "$wget_status" -eq 0 ] && [ -s "$dest.part" ]; then
      mv "$dest.part" "$dest"
      echo "✅ Hotovo: $(basename "$dest") ($(du -h "$dest" | cut -f1))"
    else
      echo "⚠️ CHYBA při stahování $(basename "$dest"), výpis wget:"
      grep -vE "^ *[0-9]+[KMG] " "$wlog" | tail -n 15
      rm -f "$dest.part"
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

# --- 3b. Modely pro oficiální ComfyUI šablony (Templates menu) ---
# Wan 2.2 14B Image to Video: 4krokové lightx2v LoRA (high + low noise)
echo "🔍 Stahuji LoRA pro Wan 2.2 I2V (4 kroky)..."
download_if_missing "$MODELS_DIR/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
download_if_missing "$MODELS_DIR/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"

# Wan 2.1 InfiniteTalk (nativní nody): základní I2V 480p model, InfiniteTalk patch, wav2vec2, VAE, lightx2v LoRA
echo "🔍 Stahuji modely pro InfiniteTalk (lip sync)..."
download_if_missing "$MODELS_DIR/diffusion_models/Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS_DIR/model_patches/wan2.1_infiniteTalk_multi_fp16.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/model_patches/wan2.1_infiniteTalk_multi_fp16.safetensors"
download_if_missing "$MODELS_DIR/audio_encoders/wav2vec2-chinese-base_fp16.safetensors" \
  "https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors"
download_if_missing "$MODELS_DIR/vae/Wan2_1_VAE_bf16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_if_missing "$MODELS_DIR/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

echo "✅ Modely pro šablony Wan 2.2 I2V a InfiniteTalk připraveny"

# --- 3c. Obrázky: Qwen-Image-2512 (text → obrázek) a Qwen-Image-Edit-2511 (úprava s referencí postavy) ---
# Obě verze jsou pod licencí Apache 2.0 (pozor: novější Qwen-Image-2.1 má nekomerční licenci, proto se nepoužívá)
echo "🔍 Stahuji modely pro obrázky (Qwen-Image)..."
download_if_missing "$MODELS_DIR/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
download_if_missing "$MODELS_DIR/vae/qwen_image_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
download_if_missing "$MODELS_DIR/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors" \
  "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"
download_if_missing "$MODELS_DIR/loras/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors" \
  "https://huggingface.co/lightx2v/Qwen-Image-2512-Lightning/resolve/main/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors"
download_if_missing "$MODELS_DIR/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
  "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
download_if_missing "$MODELS_DIR/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
  "https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
echo "✅ Modely pro obrázky připraveny"

# --- 4. Self-healing spuštění ComfyUI ---
set +e

LOG_FILE="/tmp/comfyui_start.log"
MAX_ATTEMPTS=4
ATTEMPT=1
HEALTHCHECK_SECONDS=300   # 5 min, kvůli první instalaci závislostí

apply_known_fixes() {
  local log="$1"

  # Starý driver: torch se NEpřeinstalovává (starší torch ComfyUI nepodporuje a rozbije comfy_kitchen).
  # Řešení je pod na stroji s novějším driverem.
  if grep -qi "NVIDIA driver on your system is too old" "$log"; then
    echo "🛑 Driver na tomto stroji je pro torch s CUDA 12.6 příliš starý."
    echo "   Smaž pod a vytvoř nový s filtrem CUDA verze 12.4 nebo vyšší (driver 525 a vyšší)."
    return 1
  fi

  # Jiný chybějící Python modul (ne torch)
  if grep -qi "No module named" "$log"; then
    local missing_pkg
    missing_pkg=$(grep -oP "No module named '\K[^']+" "$log" | head -n1)
    if [ -n "$missing_pkg" ] && [ "$missing_pkg" != "torch" ]; then
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

  # Pojistka: ukonči případný sirotčí proces ze zabitého předchozího pokusu
  pkill -9 -f "python3 main.py" 2>/dev/null
  sleep 2

  cd /opt/ComfyUI
  > "$LOG_FILE"

  # KLÍČOVÉ: spouštíme python3 přímo na pozadí (ne přes | tee &),
  # aby $! ukazoval na skutečný PID ComfyUI, ne na tee
  stdbuf -oL -eL python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "$LOG_FILE" 2>&1 &
  PY_PID=$!
  # Paralelně streamujeme log na konzoli (RunPod Logs)
  tail -f "$LOG_FILE" &
  TAIL_PID=$!

  SUCCESS=0
  for i in $(seq 1 $((HEALTHCHECK_SECONDS / 2))); do
    if ! kill -0 $PY_PID 2>/dev/null; then
      break   # proces spadl
    fi
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8188/ 2>/dev/null | grep -q "200"; then
      SUCCESS=1
      break
    fi
    sleep 2
  done

  kill $TAIL_PID 2>/dev/null

  if [ $SUCCESS -eq 1 ]; then
    echo "✅ ComfyUI úspěšně naběhlo, přebírám popředí procesu."
    wait $PY_PID
    exit $?
  fi

  echo "❌ ComfyUI nenaběhlo / spadlo. Analyzuji log..."
  kill -9 $PY_PID 2>/dev/null
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
