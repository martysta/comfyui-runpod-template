# ⚙️ Základní image: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev \
    build-essential wget ffmpeg libsm6 libxext6 \
 && git lfs install \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 📁 Pracovní adresář mimo /workspace (RunPod-safe)
WORKDIR /UI

# 🧠 Klon ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /UI/ComfyUI

# 📦 Instalace Python závislostí
WORKDIR /UI/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt --prefer-binary

# 🧩 Instalace ComfyUI Manageru
RUN mkdir -p /UI/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /UI/ComfyUI/custom_nodes/ComfyUI-Manager

# ✅ Kontrola main.py
RUN test -f /UI/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen!" && ls -la /UI/ComfyUI && exit 1)

# 🔗 Kompatibilita s RunPodem (RunPod hledá /workspace/ComfyUI)
RUN mkdir -p /workspace && ln -s /UI/ComfyUI /workspace/ComfyUI

# 📦 Přidání workflow a modelů (volitelné, můžeš doplnit lokálně)
COPY ./workflows /UI/ComfyUI/workflows
COPY ./models /UI/ComfyUI/models

# 📄 Přidání start.sh
COPY start.sh /UI/start.sh
RUN chmod +x /UI/start.sh

# 🌐 Instalace JupyterLab (bez tokenu)
RUN pip install jupyterlab && \
    mkdir -p /root/.jupyter && \
    echo "c.ServerApp.token = ''" > /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.password = ''" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.allow_origin = '*'" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.open_browser = False" >> /root/.jupyter/jupyter_server_config.py && \
    echo "c.ServerApp.port = 8888" >> /root/.jupyter/jupyter_server_config.py

# 🌐 Porty pro ComfyUI a JupyterLab
EXPOSE 8188
EXPOSE 8888

# 🚀 Spuštění start.sh (modely se stáhnou při startu)
CMD ["/UI/start.sh"]
