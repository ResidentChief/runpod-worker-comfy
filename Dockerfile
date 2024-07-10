# Use Nvidia CUDA base image
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    git-lfs \
    wget \
    dos2unix \
    libgl1-mesa-glx \
    libglib2.0-0 

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

ARG SKIP_DEFAULT_MODELS

# Download checkpoints include in image.
WORKDIR /comfyui/models/checkpoints
RUN wget -O ICBINPXL_v7.safetensors https://huggingface.co/residentchiefnz/Testing/resolve/main/v7_rc1.safetensors
RUN wget -O Fustercluck.safetensors https://huggingface.co/residentchiefnz/Testing/resolve/main/F2_step2.safetensors
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    && pip3 install --no-cache-dir xformers \
    && pip3 install --no-cache-dir -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# ADD IDM-VTON Custom Nodes
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/TemryL/ComfyUI-IDM-VTON
WORKDIR /comfyui/custom_nodes/ComfyUI-IDM-VTON/models
RUN rm -f .gitkeep
RUN git clone https://huggingface.co/yisol/IDM-VTON .

# Add Segment Anything Custom Nodes
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/storyicon/comfyui_segment_anything
WORKDIR /comfyui/models/grounding-dino
RUN wget https://huggingface.co/ShilongLiu/GroundingDINO/resolve/main/groundingdino_swinb_cogcoor.pth
COPY /models/GroundingDINO_SwinB.cfg.py ./GroundingDINO_SwinB.cfg.py
WORKDIR /comfyui/models/sams
RUN wget https://huggingface.co/lkeab/hq-sam/resolve/main/sam_hq_vit_h.pth

# Add controlnet preprocessor 
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux 
WORKDIR /comfyui/custom_nodes/comfyui_controlnet_aux/LayerNorm/DensePose-TorchScript-with-hint-image
RUN wget https://huggingface.co/LayerNorm/DensePose-TorchScript-with-hint-image/resolve/main/densepose_r50_fpn_dl.torchscript

# Add Rembg
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/Jcd1230/rembg-comfyui-node
WORKDIR /root/.u2net/
RUN wget https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx

# Add InstantID
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/nosiu/comfyui-instantId-faceswap
WORKDIR /comfyui/models/insightface/models/antelopev2
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/antelopev2.zip
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx
RUN wget https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx
WORKDIR /comfyui/models/ipadapter
RUN wget https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin
WORKDIR /comfyui/models/controlnet/ControlNetModel
RUN wget https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/config.json
RUN wget https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors

# Install requirements for custom nodes
WORKDIR /comfyui/custom_nodes/ComfyUI-IDM-VTON
RUN pip3 install --no-cache-dir -r requirements.txt
WORKDIR /comfyui/custom_nodes/comfyui_segment_anything
RUN pip3 install --no-cache-dir -r requirements.txt
WORKDIR /comfyui/custom_nodes/comfyui_controlnet_aux
RUN pip3 install --no-cache-dir -r requirements.txt
WORKDIR /comfyui/custom_nodes/rembg-comfyui-node
RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip3 install --no-cache-dir insightface

# Copy mannequin images to input folder
COPY /assets/* /comfyui/input/

# Return to root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./

# Convert line endings of the scripts
RUN dos2unix /start.sh

# Make the script executable
RUN chmod +x /start.sh

# Start the container
CMD /start.sh
