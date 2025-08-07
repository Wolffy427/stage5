MODEL="Qwen2-7B"
TOKENIZER="/root/autodl-tmp/models/Qwen/Qwen2-7B"
SWANLAB_API_KEY="EOQCnWdMl5RFgMpUiQpTd"
NAME=${MODEL}
evalscope perf \
  --parallel 4 8 16 32\
  --model ${MODEL} \
  --url http://127.0.0.1:8801/v1/chat/completions \
  --api openai \
  --dataset random \
  --min-tokens 256 \
  --max-tokens 512 \
  --prefix-length 64 \
  --min-prompt-length 1024 \
  --max-prompt-length 2048 \
  --number 4 8 16 32\
  --tokenizer-path ${TOKENIZER} \
  --swanlab-api-key ${SWANLAB_API_KEY} \
  --name Qwen2-7B-tp-2 \
  --debug