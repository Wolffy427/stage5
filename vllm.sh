# 模型配置变量
# MODEL_PATH="/home/aligames/project/stage5/models/Qwen2.5-3B-Instruct-awq-w4a16"
# MODEL_NAME="Qwen2.5-3B-Instruct-awq-w4a16"
MODEL_PATH="/home/aligames/project/stage5/models/Qwen/Qwen2.5-3B-Instruct"
MODEL_NAME="Qwen2.5-3B-Instruct"

export CUDA_VISIBLE_DEVICES=2

nohup python -m vllm.entrypoints.openai.api_server --model ${MODEL_PATH} \
  --host 0.0.0.0 \
  --port 8801 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 4096 \
  --max-num-seqs 128 \
  --served-model-name ${MODEL_NAME} \
  > logs/vllm.log 2>&1 &
pid=$!
echo $pid > logs/vllm.pid