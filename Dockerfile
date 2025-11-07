# ⚙️ Base image: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev build-essential wget ffmpeg \
    libsm6 libxext6 ca-certificates && \
    git lfs install && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 📁 Instalace mimo /workspace (RunPod-safe)
WORKDIR /UI

# 🧠 Klon oficiálního ComfyUI repozitáře
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /UI/ComfyUI

# 📦 Instalace Python závislostí
WORKDIR /UI/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt --prefer-binary

# 🧩 Instalace ComfyUI Manageru + HWStats s fallbackem
RUN mkdir -p /UI/ComfyUI/custom_nodes && \
    (git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /UI/ComfyUI/custom_nodes/ComfyUI-Manager || echo "⚠️ ComfyUI-Manager repo nedostupné") && \
    (git clone --depth=1 https://github.com/ltdrdata/ComfyUI-HWStats.git /UI/ComfyUI/custom_nodes/ComfyUI-HWStats || echo "⚠️ HWStats repo nedostupné")

# ✅ Kontrola main.py
RUN test -f /UI/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen!" && ls -la /UI/ComfyUI && exit 1)

# 🔗 Kompatibilita s RunPodem
RUN mkdir -p /workspace && ln -s /UI/ComfyUI /workspace/ComfyUI

# ⚡️ Instalace JupyterLite
RUN pip3 install jupyterlite==0.4.0

# 🌐 Porty pro webové rozhraní
EXPOSE 8188 8000

# 🚀 Spuštění ComfyUI + JupyterLite současně
CMD ["bash", "-c", "\
python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188 & \
jupyter lite serve --port 8000 --ip 0.0.0.0 \
"]
