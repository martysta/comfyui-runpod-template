# ⚙️ Base image: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
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

# 📁 Instalace mimo /workspace (RunPod-safe)
WORKDIR /UI

# 🧠 Klon ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /UI/ComfyUI

# 📦 Python závislosti ComfyUI
WORKDIR /UI/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir -r requirements.txt --prefer-binary

# 🧩 Instalace ComfyUI Manageru
RUN mkdir -p /UI/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /UI/ComfyUI/custom_nodes/ComfyUI-Manager

# 🛠️ Instalace JupyterLab a knihoven pro HW monitor
RUN pip3 install jupyterlab psutil torch gpustat --prefer-binary

# 🧩 Custom Node pro HWStats
RUN mkdir -p /UI/ComfyUI/custom_nodes/ComfyUI-HW-Stats
RUN echo 'from ComfyUI import Node\nimport psutil, gpustat, torch\n\nclass HWStatsNode(Node):\n    @classmethod\n    def INPUT_TYPES(cls):\n        return {}\n\n    @classmethod\n    def RETURN_TYPES(cls):\n        return ("STRING",)\n\n    @classmethod\n    def FUNCTION(cls, **kwargs):\n        cpu_percent = psutil.cpu_percent(interval=0.5)\n        ram_percent = psutil.virtual_memory().percent\n        if torch.cuda.is_available():\n            try:\n                gpus = gpustat.GPUStatCollection.new_query()\n                gpu_list = [f"{gpu.index}:{gpu.utilization}%" for gpu in gpus.gpus]\n                gpu_info = ", ".join(gpu_list)\n            except:\n                gpu_info = "GPU: error"\n        else:\n            gpu_info = "GPU: none"\n        status = f"CPU: {cpu_percent}% | RAM: {ram_percent}% | {gpu_info}"\n        return (status,)' > /UI/ComfyUI/custom_nodes/ComfyUI-HW-Stats/HWStats.py
RUN touch /UI/ComfyUI/custom_nodes/ComfyUI-HW-Stats/__init__.py

# 📝 Vytvoření default workflow s HWStatsNode
RUN mkdir -p /UI/ComfyUI/workflows && \
    cat << 'EOF' > /UI/ComfyUI/workflows/default_workflow.json
{
  "nodes": [
    {
      "type": "HWStatsNode",
      "id": "hw1",
      "outputs": ["status"]
    },
    {
      "type": "Label",
      "id": "label1",
      "inputs": {"INPUT": "hw1.status"}
    }
  ],
  "connections": [
    {"from": "hw1.status", "to": "label1.INPUT"}
  ]
}
EOF

# ✅ Kontrola main.py
RUN test -f /UI/ComfyUI/main.py || (echo "❌ main.py nebyl nalezen!" && ls -la /UI/ComfyUI && exit 1)

# 🔗 RunPod symlink
RUN mkdir -p /workspace && ln -s /UI/ComfyUI /workspace/ComfyUI

# 🌐 Porty pro ComfyUI a JupyterLab
EXPOSE 8188
EXPOSE 8888

# 🚀 Spuštění ComfyUI + default workflow + JupyterLab
CMD ["bash", "-c", "\
python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --load-workflow /UI/ComfyUI/workflows/default_workflow.json & \
jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser \
"]
