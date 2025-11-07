FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# 🧱 Základní balíčky
RUN apt update && apt install -y git python3 python3-pip wget

# 🧠 Instalace ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN pip3 install -r requirements.txt

# 🧩 Instalace Node Manageru
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager /workspace/ComfyUI/custom_nodes/ComfyUI-Manager

# 🎞️ AnimateDiff Evolved
RUN git clone https://github.com/SipherAGI/comfyui-animatediff /workspace/ComfyUI/custom_nodes/comfyui-animatediff

# 🎨 SDXL Prompt Styler
RUN git clone https://github.com/melMass/ComfyUI-SDXLPromptStyler /workspace/ComfyUI/custom_nodes/ComfyUI-SDXLPromptStyler

# 🌐 Port pro web UI
EXPOSE 8188

# 🚀 Spuštění ComfyUI
CMD ["python3", "main.py"]
