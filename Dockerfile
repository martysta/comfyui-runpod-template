FROM nvidia/cuda:12.4.1-devel-ubuntu22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs python3 python3-pip python3-dev \
    build-essential wget curl ffmpeg libsm6 libxext6 \
    && git lfs install \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# curl je nutný: start.sh přes něj kontroluje, jestli ComfyUI naběhlo

# Pevné verze: ComfyUI release + torch 2.14.1 sestavený pro CUDA 12.6 (stačí driver 525+,
# takže běží i na starších strojích jako A40). Pro 12.8 torch 2.14.1 sestavení nemá.
# Karty Blackwell (RTX 5090, RTX PRO 6000, B200) potřebují CUDA 12.8+ a na tomhle image nepoběží.
# Constraints soubor zajistí, že žádný custom node ani pozdější pip install torch nepřepíše.
ARG COMFYUI_VERSION=v0.42.5
ENV PIP_CONSTRAINT=/opt/constraints.txt
RUN printf "torch==2.14.1+cu126\ntorchvision==0.29.1+cu126\n" > /opt/constraints.txt

# ZMĚNA: instalujeme do /opt/ComfyUI, ne do /workspace
WORKDIR /opt
RUN git clone --depth=1 --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI
WORKDIR /opt/ComfyUI
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install --no-cache-dir torch==2.14.1+cu126 torchvision==0.29.1+cu126 \
       --index-url https://download.pytorch.org/whl/cu126 \
    && pip3 install --no-cache-dir -r requirements.txt --prefer-binary

RUN mkdir -p custom_nodes \
    && git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager

RUN git clone --depth=1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git custom_nodes/ComfyUI-WanVideoWrapper \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt --prefer-binary

RUN git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git custom_nodes/ComfyUI-VideoHelperSuite \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt --prefer-binary

RUN git clone --depth=1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git custom_nodes/ComfyUI-Frame-Interpolation \
    && cd custom_nodes/ComfyUI-Frame-Interpolation && python3 install.py

RUN git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git custom_nodes/ComfyUI-KJNodes \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-KJNodes/requirements.txt --prefer-binary

RUN git clone --depth=1 https://github.com/Azornes/Comfyui-Resolution-Master.git custom_nodes/Comfyui-Resolution-Master

RUN git clone --depth=1 https://github.com/x3bits/ComfyUI-Power-Flow.git custom_nodes/ComfyUI-Power-Flow

RUN git clone --depth=1 https://github.com/rgthree/rgthree-comfy.git custom_nodes/rgthree-comfy \
    && pip3 install --no-cache-dir -r custom_nodes/rgthree-comfy/requirements.txt --prefer-binary

RUN git clone --depth=1 https://github.com/willmiao/ComfyUI-Lora-Manager.git custom_nodes/ComfyUI-Lora-Manager \
    && pip3 install --no-cache-dir -r custom_nodes/ComfyUI-Lora-Manager/requirements.txt --prefer-binary

RUN test -f /opt/ComfyUI/main.py || (echo "main.py chybí!" && exit 1)

# start.sh jde taky mimo /workspace
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

EXPOSE 8188
CMD ["/opt/start.sh"]
