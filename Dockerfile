FROM runpod/worker-comfyui:5.11.0-base

ARG COMFYUI_TAG=v0.39.2
ARG COMFYUI_GGUF_COMMIT=373048b8403a7820620065210a691263d4da0a61

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Qwen Image 2.1 requires a newer ComfyUI than the 5.11.0 worker base ships.
RUN git -C /comfyui fetch --depth 1 origin "refs/tags/${COMFYUI_TAG}:refs/tags/${COMFYUI_TAG}" \
    && git -C /comfyui checkout --detach "${COMFYUI_TAG}" \
    && uv pip install -r /comfyui/requirements.txt \
    && uv pip install "transformers>=4.50.3,<5" "huggingface-hub<1.0"

# Pin the maintained fork that recognizes the qwen_image21 GGUF architecture.
RUN git clone --filter=blob:none https://github.com/leejet/ComfyUI-GGUF.git /comfyui/custom_nodes/ComfyUI-GGUF \
    && git -C /comfyui/custom_nodes/ComfyUI-GGUF checkout --detach "${COMFYUI_GGUF_COMMIT}" \
    && uv pip install -r /comfyui/custom_nodes/ComfyUI-GGUF/requirements.txt

RUN cp /handler.py /handler_base.py

COPY handler_qwen.py /handler.py
COPY workflow.json /qwen-image-21-workflow.json
COPY start-qwen.sh /start-qwen.sh
RUN chmod +x /start-qwen.sh

ENV COMFY_LOG_LEVEL=INFO
ENV NETWORK_VOLUME_DEBUG=false
ENV QWEN_MODEL_REPO=abenzerps/Qwen-Image-2.1-Uncensored-Quantized

CMD ["/start-qwen.sh"]
