# 🧱 Základní image s Pythonem a nástroji
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# 🧩 Systémové balíčky
RUN apt-get update && apt-get install -y \
    git wget python3 python3-pip python3-venv \
    ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# 🧰 Nastavení pracovního adresáře
WORKDIR /UI

# 🧩 Instalace ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && pip install --upgrade pip && pip install -r requirements.txt

# 🧩 Instalace custom nodů (ComfyUI Manager + HWStats)
RUN mkdir -p /UI/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-HWStats.git /UI/ComfyUI/custom_nodes/ComfyUI-HWStats && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /UI/ComfyUI/custom_nodes/ComfyUI-Manager || true

# 🧠 HWStats závislosti + automatické workflow
RUN pip3 install psutil GPUtil pynvml && \
    mkdir -p /UI/ComfyUI/workflows && \
    echo '{ \
      "last_node_id": 1, \
      "last_link_id": 0, \
      "nodes": [ \
        { \
          "id": 1, \
          "type": "HWStatsNode", \
          "pos": [100, 100], \
          "size": [200, 100], \
          "flags": {}, \
          "order": 1, \
          "mode": 0 \
        } \
      ] \
    }' > /UI/ComfyUI/workflows/hwstats.json

# 🧩 Instalace JupyterLab (bez tokenu, bez hesla)
RUN pip install jupyterlab

# 🧹 Porty
EXPOSE 8188 8888

# 🚀 Spuštění obou služeb: ComfyUI + JupyterLab
CMD ["bash", "-c", "\
python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --force-fp16 & \
jupyter lab --ip 0.0.0.0 --port 8888 --allow-root --NotebookApp.token='' --NotebookApp.password='' \
"]
