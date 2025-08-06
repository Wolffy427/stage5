from evalscope.perf.main import run_perf_benchmark
 
# 配置性能测试
task_cfg = {
    'url': 'http://127.0.0.1:8801/v1/chat/completions',  # API端点
    'parallel': [1, 8, 16, 32, 64, 128],  # 并发请求数量
    'model': 'Qwen2.5-3B-Instruct-awq-w4a16',  # 模型名称或标识符
    'number': [1, 8, 16, 32, 64, 128],  # 要发出的总请求数量
    'api': 'openai',  # API类型（此例中为OpenAI兼容）
    'dataset': 'openqa',  # 用于查询的数据集
    'debug': True,  # 启用调试日志
}
 
# 运行基准测试
run_perf_benchmark(task_cfg)