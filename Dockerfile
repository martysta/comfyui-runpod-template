FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Základní balíčky
RUN apt update && apt install -y git python3 python3-pip wget ffmpeg libsm6 libxext6

# 🧠 Instalace ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN pip3 install -r requirements.txt

# 🧩 Custom Nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager /workspace/ComfyUI/custom_nodes/ComfyUI-Manager
RUN git clone https://github.com/SipherAGI/comfyui-animatediff /workspace/ComfyUI/custom_nodes/comfyui-animatediff
RUN git clone https://github.com/twri/sdxl_prompt_styler /workspace/ComfyUI/custom_nodes/sdxl_prompt_styler

# 📦 Motion Module (AnimateDiff)
RUN mkdir -p /workspace/models/motion_module && \
    wget -O /workspace/models/motion_module/mm_sd15.ckpt https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd15.ckpt

# 🧪 Kontrola existence main.py
RUN test -f /workspace/ComfyUI/main.py || (echo "❌ main.py not found!" && exit 1)

# 🌐 Port pro web UI
EXPOSE 8188

# 🚀 Spuštění ComfyUI
CMD ["python3", "/workspace/ComfyUI/main.py"]
