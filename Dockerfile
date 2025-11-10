# ⚙️ Základní image: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
RUN echo "📦 Instalace systémových balíčků..." \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev \
    build-essential wget ffmpeg libsm6 libxext6 curl \
 && git lfs install \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && echo "✅ Systémové balíčky nainstalovány"

# 📁 Pracovní adresář
WORKDIR /workspace

# 📄 Přidání start.sh
COPY ./start.sh ./start.sh
RUN chmod +x ./start.sh \
 && echo "📂 Obsah /workspace po COPY:" && ls -la /workspace \
 && echo "📂 Obsah rootu buildu:" && ls -la / \
 && test -f ./start.sh || (echo "❌ start.sh nebyl zkopírován!" && exit 1) \
 && echo "✅ start.sh připraven"

# 📥 Klonování ComfyUI do /workspace/ComfyUI
RUN echo "📥 Klonování ComfyUI..." \
 && git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI \
 && echo "✅ ComfyUI klonováno"

# 🐍 Instalace Python závislostí
WORKDIR /workspace/ComfyUI
RUN echo "🐍 Instalace Python závislostí..." \
 && pip3 install --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt --prefer-binary \
 && echo "✅ Python závislosti nainstalovány"

# 🧩 Instalace ComfyUI Manageru
RUN echo "🧩 Přidání ComfyUI Manageru..." \
 && mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /workspace/ComfyUI/custom_nodes/ComfyUI-Manager \
 && echo "✅ ComfyUI Manager přidán"

# 🔍 Kontrola main.py
RUN echo "🔍 Kontrola main.py..." \
 && test -f /workspace/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen!" && ls -la /workspace/ComfyUI && exit 1) \
 && echo "✅ main.py nalezen"

# 🌐 Instalace JupyterLab (bez tokenu)
RUN echo "🌐 Instalace JupyterLab..." \
 && pip install jupyterlab \
 && mkdir -p /root/.jupyter \
 && echo "c.ServerApp.token = ''" > /root/.jupyter/jupyter_server_config.py \
 && echo "c.ServerApp.password = ''" >> /root/.jupyter/jupyter_server_config.py \
 && echo "c.ServerApp.allow_origin = '*'" >> /root/.jupyter/jupyter_server_config.py \
 && echo "c.ServerApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_server_config.py \
 && echo "c.ServerApp.open_browser = False" >> /root/.jupyter/jupyter_server_config.py \
 && echo "c.ServerApp.port = 8888" >> /root/.jupyter/jupyter_server_config.py \
 && echo "✅ JupyterLab připraven"

# 🌐 Porty pro ComfyUI a JupyterLab
EXPOSE 8188
EXPOSE 8888

# 🚀 Spuštění start.sh
CMD ["bash", "./start.sh"]
