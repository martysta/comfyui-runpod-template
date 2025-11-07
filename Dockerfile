# ⚙️ Základní image s CUDA 12.2 a Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Instalace základních balíčků
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    python3-pip \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# 📁 Pracovní adresář
WORKDIR /workspace

# 🧠 Stažení oficiálního ComfyUI repozitáře
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

# ✅ Ověření, že main.py existuje po klonu
RUN test -f /workspace/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen po klonu!" && ls -la /workspace/ComfyUI && exit 1)

# 📦 Instalace Python závislostí
WORKDIR /workspace/ComfyUI
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt

# 🧩 Instalace ověřeného ComfyUI-Manageru
RUN mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /workspace/ComfyUI/custom_nodes/ComfyUI-Manager

# 🔍 Závěrečná kontrola souboru main.py
RUN test -f /workspace/ComfyUI/main.py || (echo "❌ main.py stále chybí!" && ls -la /workspace/ComfyUI && exit 1)

# 🌐 Expose port
EXPOSE 8188

# 🚀 Spuštění ComfyUI (RunPod kompatibilní)
CMD ["python3", "/workspace/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188", "--no-auto-launch"]
