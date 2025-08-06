curl -X GET http://127.0.0.1:8801/v1/models 


curl -X POST http://127.0.0.1:8801/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-3B-Instruct-awq",
    "messages": [
      {
        "role": "user",
        "content": "你好"
      }
    ]
  }'
