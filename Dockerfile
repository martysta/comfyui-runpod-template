# ⚙️ Base: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové závislosti (včetně kompilátorů pro buildy Python balíčků)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
 && git lfs install \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# 📁 Pracovní adresář
WORKDIR /workspace

# 🧠 Klon ComfyUI (oficiální repo)
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

# 📦 Instalace Python závislostí s robustnější konfigurací
WORKDIR /workspace/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt || (echo "⚠️ Instalace requirements.txt selhala, zkouším fallback" && pip3 install --no-cache-dir -r requirements.txt --prefer-binary)

# 🧩 Ověřený ComfyUI-Manager
RUN mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /workspace/ComfyUI/custom_nodes/ComfyUI-Manager

# ✅ Kontrola přítomnosti main.py
RUN test -f /workspace/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen!" && ls -la /workspace/ComfyUI && exit 1)

# 🌐 Port pro webové UI
EXPOSE 8188

# 🚀 Spuštění ComfyUI (RunPod kompatibilní)
CMD ["python3", "/workspace/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188", "--no-auto-launch"]
