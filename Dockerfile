FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# Základní balíčky
RUN apt update && apt install -y git python3 python3-pip wget

# Instalace ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN pip3 install -r requirements.txt

# Port pro web UI
EXPOSE 8188

# Spuštění ComfyUI
CMD ["python3", "main.py"]
