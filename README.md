# VLLM 压测工具

这是一个基于 Locust 的 VLLM 服务压测工具，可以测试 VLLM 服务的并发性能、延迟和吞吐量。

## 文件说明

- `serve.sh`: VLLM 服务启动脚本
- `test.py`: 基于 Locust 的压测代码
- `test.sh`: 压测启动脚本
- `data/content_1.csv`: 测试数据文件

## 使用方法

### 1. 部署 VLLM 服务

```bash
# 部署服务（自动启动）
./test.sh deploy

# 或者自定义模型路径
MODEL_PATH=/path/to/your/model ./test.sh deploy
```

### 2. 运行压测

#### 方式一：Web UI 模式（推荐）
```bash
# 运行压测（如果服务未启动会自动部署）
./test.sh test

# 然后在浏览器中访问 http://localhost:8089
# 在 Web 界面中设置用户数、启动速率等参数
```

#### 方式二：无头模式
```bash
# 使用默认配置运行
./test.sh test -h

# 或者自定义配置
USERS=20 SPAWN_RATE=5 RUN_TIME=120s ./test.sh test -h
```

### 3. 管理服务

```bash
# 查看服务状态
./test.sh status

# 查看服务日志
./test.sh logs

# 停止并卸载服务
./test.sh undeploy
```

## 配置参数

### 服务配置
- `MODEL_PATH`: 模型路径 (默认: /root/autodl-tmp/stage5/models/Qwen/Qwen2-7B-Instruct)
- `SERVE_HOST`: 服务主机 (默认: 0.0.0.0)
- `SERVE_PORT`: 服务端口 (默认: 8000)
- `GPU_MEMORY_UTILIZATION`: GPU 内存利用率 (默认: 0.8)
- `MAX_MODEL_LEN`: 最大模型长度 (默认: 4096)

### 压测配置
- `HOST`: 目标服务地址 (默认: http://localhost:8000)
- `USERS`: 并发用户数 (默认: 10)
- `SPAWN_RATE`: 每秒启动用户数 (默认: 2)
- `RUN_TIME`: 运行时间 (默认: 60s)
- `WEB_PORT`: Web UI 端口 (默认: 8089)
- `LOGLEVEL`: 日志级别 (默认: INFO)

## 测试指标

压测工具会统计以下指标：

- **并发性能**: 同时处理的请求数量
- **延迟指标**: 
  - 平均响应时间
  - 最小/最大响应时间
  - P50/P95/P99 响应时间
- **吞吐量**: 每秒处理的请求数 (RPS)
- **成功率**: 请求成功的百分比

## 输出文件

压测结果会保存在 `logs/` 目录下：
- `locust_test_YYYYMMDD_HHMMSS.log`: 详细日志
- `report_YYYYMMDD_HHMMSS.html`: HTML 格式的测试报告 (无头模式)
- `stats_YYYYMMDD_HHMMSS_stats.csv`: CSV 格式的统计数据 (无头模式)

## 依赖安装

```bash
pip install locust
pip install vllm
```

## 注意事项

1. 确保 VLLM 服务已正常启动并可访问
2. 根据服务器性能调整并发用户数，避免过载
3. 测试数据文件 `data/content_1.csv` 包含了 20 个测试问题
4. 可以根据需要修改测试数据或添加更多测试场景
5. 建议先用较小的并发数进行测试，然后逐步增加

## 示例命令

```bash
# 部署 VLLM 服务
./test.sh deploy

# 运行压测 (Web UI 模式)
./test.sh test

# 运行无头模式压测
./test.sh test -h

# 自定义参数压测
USERS=50 SPAWN_RATE=10 RUN_TIME=300s ./test.sh test -h

# 查看服务状态
./test.sh status

# 停止服务
./test.sh undeploy
```