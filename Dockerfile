# ⚙️ Základní image: CUDA 12.2 + Ubuntu 22.04
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Systémové balíčky
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev \
    build-essential wget ffmpeg libsm6 libxext6 \
 && git lfs install \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 📁 Instalace mimo /workspace (RunPod-safe)
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

# 📦 Přidání workflow a modelů (vlastní soubory můžeš doplnit lokálně)
COPY ./workflows /UI/ComfyUI/workflows
COPY ./models /UI/ComfyUI/models

# 🧱 Automatické stažení doporučených modelů (Flux, ControlNet, Upscaler, Face Detector)
RUN mkdir -p /UI/ComfyUI/models/unet \
    /UI/ComfyUI/models/clip \
    /UI/ComfyUI/models/vae \
    /UI/ComfyUI/models/controlnet \
    /UI/ComfyUI/models/upscale \
    /UI/ComfyUI/models/ultralytics/bbox && \

    # UNet (Flux1 Dev)
    wget -O /UI/ComfyUI/models/unet/flux1-dev-fp8.safetensors \
      https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors && \

    # CLIP encodery
    wget -O /UI/ComfyUI/models/clip/t5xxl_fp8_e4m3fn.safetensors \
      https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors && \
    wget -O /UI/ComfyUI/models/clip/clip_l.safetensors \
      https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors && \

    # VAE
    wget -O /UI/ComfyUI/models/vae/ae.safetensors \
      https://huggingface.co/ffxvs/vae-flux/resolve/main/ae.safetensors && \

    # ControlNet (InstantID)
    wget -O /UI/ComfyUI/models/controlnet/diffusion_pytorch_model.safetensors \
      https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors && \

    # Upscale
    wget -O /UI/ComfyUI/models/upscale/4x-ClearRealityV1.pth \
      https://huggingface.co/skbhadra/ClearRealityV1/resolve/main/4x-ClearRealityV1.pth && \

    # Face detection (YOLOv8m)
    wget -O /UI/ComfyUI/models/ultralytics/bbox/face_yolov8m.pt \
      https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt

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

# 🚀 Spuštění obou aplikací (ComfyUI + JupyterLab)
CMD bash -c "\
  jupyter lab --allow-root & \
  python3 /UI/ComfyUI/main.py --listen 0.0.0.0 --port 8188"
