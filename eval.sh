MODEL="Qwen2.5-3B-Instruct"
TOKENIZER="./models/Qwen/Qwen2.5-3B-Instruct"
SWANLAB_API_KEY="EOQCnWdMl5RFgMpUiQpTd"
NAME=${MODEL}
evalscope perf \
  --parallel 1 8 16 32 64 128 \
  --model ${MODEL} \
  --url http://127.0.0.1:8801/v1/chat/completions \
  --api openai \
  --dataset random \
  --min-tokens 256 \
  --max-tokens 512 \
  --prefix-length 64 \
  --min-prompt-length 1024 \
  --max-prompt-length 2048 \
  --number 1 8 16 32 64 128 \
  --tokenizer-path ${TOKENIZER} \
  --swanlab-api-key ${SWANLAB_API_KEY} \
  --name ${NAME} \
  --debug