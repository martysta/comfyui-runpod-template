# ⚙️ CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev build-essential wget ffmpeg \
    libsm6 libxext6 ca-certificates && \
    git lfs install && apt-get clean && rm -rf /var/lib/apt/lists/*

# 📁 Instalace mimo /workspace (RunPod-safe)
WORKDIR /UI

# 🧠 Klon ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /UI/ComfyUI

# 📦 Python závislosti
WORKDIR /UI/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir -r requirements.txt --prefer-binary

# 🧩 Manager + HWStats (s fallbackem)
RUN mkdir -p /UI/ComfyUI/custom_nodes && \
    (git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /UI/ComfyUI/custom_nodes/ComfyUI-Manager || echo "⚠️ Manager repo nedostupné") && \
    (git clone --depth=1 https://github.com/ltdrdata/ComfyUI-HWStats.git /UI/ComfyUI/custom_nodes/ComfyUI-HWStats || echo "⚠️ HWStats repo nedostupné")

# ✅ Kontrola main.py
RUN test -f /UI/ComfyUI/main.py || (echo "❌ main.py chybí!" && ls -la /UI/ComfyUI && exit 1)

# 🔗 Symlink pro RunPod
RUN mkdir -p /workspace && ln -s /UI/ComfyUI /workspace/ComfyUI

# 🧠 Jupyter Lab (bez tokenu, bez browseru)
RUN pip3 install jupyterlab==4.2.4 && \
    mkdir -p /root/.jupyter && \
    echo "c.ServerApp.token = ''"        > /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.password = ''"    >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.allow_origin = '*'" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.ip = '0.0.0.0'"   >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.open_browser = False" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.port = 8888"      >> /root/.jupyter/jupyter_server_config.py

# 🌐 Porty
EXPOSE 8188 8888

# 🚀 Spuštění ComfyUI + JupyterLab
CMD ["bash", "-c", "\
python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188 & \
jupyter lab --no-browser --allow-root --ip=0.0.0.0 --port=8888 \
"]
