FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev \
    build-essential wget ffmpeg libsm6 libxext6 \
    && git lfs install \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install --no-cache-dir -r requirements.txt --prefer-binary

# ComfyUI-Manager
RUN mkdir -p custom_nodes \
    && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager

# WanVideoWrapper (hlavní engine)
RUN git clone --depth=1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git custom_nodes/ComfyUI-WanVideoWrapper \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt --prefer-binary

# VideoHelperSuite (VHS_VideoCombine)
RUN git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git custom_nodes/ComfyUI-VideoHelperSuite \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt --prefer-binary

# Frame Interpolation (RIFE VFI)
RUN git clone --depth=1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git custom_nodes/ComfyUI-Frame-Interpolation \
    && cd custom_nodes/ComfyUI-Frame-Interpolation && python3 install.py

# KJNodes (ImageResizeKJv2, GetImageSizeAndCount, ImageBatchExtendWithOverlap)
RUN git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git custom_nodes/ComfyUI-KJNodes \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-KJNodes/requirements.txt --prefer-binary

# Resolution Master
RUN git clone --depth=1 https://github.com/Azornes/Comfyui-Resolution-Master.git custom_nodes/Comfyui-Resolution-Master

# Power Flow (For Loop / logika)
RUN git clone --depth=1 https://github.com/x3bits/ComfyUI-Power-Flow.git custom_nodes/ComfyUI-Power-Flow

# rgthree (Set/Get nody)
RUN git clone --depth=1 https://github.com/rgthree/rgthree-comfy.git custom_nodes/rgthree-comfy \
    && pip3 install --no-cache-dir -r custom_nodes/rgthree-comfy/requirements.txt --prefer-binary

# LoRA Manager (usnadní doinstalování SVI/lightx2v LoRA přímo z UI)
RUN git clone --depth=1 https://github.com/willmiao/ComfyUI-Lora-Manager.git custom_nodes/ComfyUI-Lora-Manager \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-Lora-Manager/requirements.txt --prefer-binary

RUN test -f /workspace/ComfyUI/main.py || (echo "main.py chybí!" && exit 1)

COPY start.sh /workspace/start.sh
RUN chmod +x /workspace/start.sh

EXPOSE 8188

CMD ["/workspace/start.sh"]
