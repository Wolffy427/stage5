# 模型配置变量
MODEL_PATH="./models/Qwen/Qwen2.5-3B-Instruct"
MODEL_NAME="Qwen2.5-3B-Instruct"

export CUDA_VISIBLE_DEVICES=2

nohup vllm serve ${MODEL_PATH} \
  --host 0.0.0.0 \
  --port 8801 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 4096 \
  --max-num-seqs 128 \
  --served-model-name ${MODEL_NAME} \
  > outputs/vllm.log 2>&1 &