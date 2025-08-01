#!/bin/bash

# VLLM服务启动脚本
# 默认配置，可根据实际需求调整

MODEL_PATH="${MODEL_PATH:-/root/autodl-tmp/stage5/models/Qwen/Qwen2-7B-Instruct}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.8}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

echo "启动VLLM服务..."
echo "模型路径: $MODEL_PATH"
echo "服务地址: $HOST:$PORT"
echo "GPU内存利用率: $GPU_MEMORY_UTILIZATION"
echo "最大模型长度: $MAX_MODEL_LEN"

# 启动vllm服务
vllm serve "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --max-model-len "$MAX_MODEL_LEN" \
    --served-model-name "llm-model" \
    --trust-remote-code