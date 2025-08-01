# EvalScope 评估工具使用指南

这是一个完善的 EvalScope 评估工具套件，提供了多种方式来评估大语言模型的性能。

## 文件说明

- `evalscope.sh` - 增强的 Bash 脚本，提供完整的服务管理和评估功能
- `evalscope_enhanced.py` - Python 增强脚本，支持配置文件和高级功能
- `evalscope_config.yaml` - 配置文件，定义评估参数和数据集

## 功能特性

### 🚀 核心功能
- **自动服务管理**: 自动启动/停止 VLLM 服务
- **健康检查**: 服务状态监控和健康检查
- **多数据集支持**: 支持 GSM8K、MMLU、C-Eval 等多个数据集
- **评估套件**: 预设的评估组合（快速、数学、综合等）
- **错误处理**: 完善的错误处理和重试机制
- **日志管理**: 详细的日志记录和管理
- **结果分析**: 自动生成评估报告

### 📊 支持的数据集
- **GSM8K**: 小学数学应用题
- **MMLU**: 多任务语言理解评估
- **C-Eval**: 中文综合评估
- **HumanEval**: 代码生成评估
- **RACE**: 阅读理解评估

### 🎯 预设评估套件
- **quick**: 快速评估（5个样本）
- **math**: 数学推理评估
- **comprehensive**: 综合能力评估
- **chinese**: 中文能力评估
- **coding**: 代码生成评估

## 安装依赖

```bash
# 安装必要的 Python 包
pip install vllm evalscope pyyaml requests

# 确保模型文件存在
ls /root/autodl-tmp/stage5/models/Qwen/Qwen2-7B-Instruct/
```

## 使用方法

### 方式一：使用 Bash 脚本（推荐）

#### 1. 查看帮助
```bash
./evalscope.sh
```

#### 2. 启动服务并运行评估
```bash
# 使用默认配置（GSM8K，10个样本）
./evalscope.sh start

# 自定义数据集和样本数
DATASETS=mmlu LIMIT=20 ./evalscope.sh start

# 使用多个数据集
DATASETS="gsm8k,mmlu" LIMIT=15 ./evalscope.sh start
```

#### 3. 仅启动服务
```bash
./evalscope.sh serve
```

#### 4. 仅运行评估（需要服务已启动）
```bash
./evalscope.sh eval
```

#### 5. 查看服务状态
```bash
./evalscope.sh status
```

#### 6. 查看服务日志
```bash
./evalscope.sh logs
```

#### 7. 停止服务
```bash
./evalscope.sh stop
```

#### 8. 清理旧结果
```bash
./evalscope.sh clean
```

### 方式二：使用 Python 脚本（高级功能）

#### 1. 查看帮助
```bash
./evalscope_enhanced.py --help
```

#### 2. 列出可用资源
```bash
# 列出评估套件
./evalscope_enhanced.py list suites

# 列出数据集
./evalscope_enhanced.py list datasets
```

#### 3. 使用评估套件
```bash
# 快速评估
./evalscope_enhanced.py start --suite quick

# 数学评估
./evalscope_enhanced.py start --suite math

# 综合评估
./evalscope_enhanced.py start --suite comprehensive
```

#### 4. 自定义评估
```bash
# 指定数据集和样本数
./evalscope_enhanced.py start --datasets gsm8k mmlu --limit 25

# 仅运行评估
./evalscope_enhanced.py eval --datasets ceval --limit 30
```

#### 5. 服务管理
```bash
# 启动服务
./evalscope_enhanced.py serve

# 停止服务
./evalscope_enhanced.py stop
```

## 配置文件

### 修改配置
编辑 `evalscope_config.yaml` 文件来自定义配置：

```yaml
# 服务配置
service:
  host: "0.0.0.0"
  port: 8801
  model_name: "qwen2.5"
  
# 模型配置
model:
  path: "/path/to/your/model"
  
# 生成配置
generation:
  max_tokens: 2048
  temperature: 0.0
```

### 添加新数据集
在配置文件中添加新的数据集：

```yaml
evaluation:
  datasets:
    your_dataset:
      name: "your_dataset"
      limit: 20
      description: "你的数据集描述"
```

### 创建新的评估套件
```yaml
suites:
  custom:
    datasets: ["gsm8k", "your_dataset"]
    limit: 30
    description: "自定义评估套件"
```

## 环境变量配置

可以通过环境变量覆盖默认配置：

```bash
# 模型相关
export MODEL_PATH="/path/to/your/model"
export MODEL_NAME="your_model_name"

# 服务相关
export SERVE_HOST="0.0.0.0"
export SERVE_PORT="8801"
export GPU_MEMORY_UTILIZATION="0.8"
export MAX_MODEL_LEN="4096"

# 评估相关
export DATASETS="gsm8k,mmlu"
export LIMIT="20"
export WORK_DIR="/path/to/work/dir"
export TIMEOUT="300"

# 生成相关
export MAX_TOKENS="2048"
export TEMPERATURE="0.0"
```

## 输出文件

评估结果会保存在工作目录下，按时间戳组织：

```
evalscope/
├── 20250801_170355/
│   ├── configs/
│   │   └── task_config.yaml
│   ├── logs/
│   │   └── eval_log.log
│   ├── predictions/
│   │   └── model_predictions.json
│   ├── eval_config.json          # 评估配置
│   ├── results_summary.json      # 结果摘要
│   ├── evaluation_report.json    # 详细报告
│   └── evaluation_report.txt     # 文本报告
```

## 故障排除

### 1. 服务启动失败
```bash
# 检查服务日志
./evalscope.sh logs

# 检查端口是否被占用
netstat -tlnp | grep 8801

# 检查 GPU 内存
nvidia-smi
```

### 2. 评估连接失败
```bash
# 检查服务状态
./evalscope.sh status

# 测试 API 连接
curl http://localhost:8801/health

# 检查防火墙设置
sudo ufw status
```

### 3. 内存不足
```bash
# 降低 GPU 内存利用率
GPU_MEMORY_UTILIZATION=0.6 ./evalscope.sh start

# 减少最大模型长度
MAX_MODEL_LEN=2048 ./evalscope.sh start

# 减少评估样本数
LIMIT=5 ./evalscope.sh start
```

### 4. 评估超时
```bash
# 增加超时时间
TIMEOUT=600 ./evalscope.sh start

# 减少生成长度
MAX_TOKENS=1024 ./evalscope.sh start
```

## 性能优化

### 1. GPU 优化
- 调整 `GPU_MEMORY_UTILIZATION` 参数
- 使用合适的 `MAX_MODEL_LEN`
- 考虑使用量化模型

### 2. 评估优化
- 使用较小的 `LIMIT` 进行快速测试
- 并行评估多个数据集
- 使用缓存避免重复计算

### 3. 网络优化
- 确保网络连接稳定
- 调整 `TIMEOUT` 参数
- 使用本地模型避免下载

## 最佳实践

1. **开始前检查**：确保模型文件完整，GPU 内存充足
2. **渐进式测试**：先用小样本测试，再进行完整评估
3. **监控资源**：评估过程中监控 GPU 和内存使用
4. **保存结果**：定期备份重要的评估结果
5. **版本管理**：记录模型版本和评估配置

## 示例工作流

```bash
# 1. 检查环境
./evalscope.sh status

# 2. 快速测试
LIMIT=3 ./evalscope.sh start

# 3. 数学能力评估
DATASETS=gsm8k LIMIT=50 ./evalscope.sh start

# 4. 综合评估
./evalscope_enhanced.py start --suite comprehensive

# 5. 查看结果
ls -la evalscope/

# 6. 清理旧结果
./evalscope.sh clean

# 7. 停止服务
./evalscope.sh stop
```

## 常见问题

**Q: 如何添加新的数据集？**
A: 在 `evalscope_config.yaml` 中添加数据集配置，然后使用 `--datasets` 参数指定。

**Q: 如何修改生成参数？**
A: 修改配置文件中的 `generation` 部分，或使用环境变量覆盖。

**Q: 评估结果保存在哪里？**
A: 默认保存在 `evalscope/` 目录下，按时间戳组织。

**Q: 如何并行评估多个模型？**
A: 使用不同的端口和工作目录，启动多个评估实例。

**Q: 如何自定义评估指标？**
A: 需要修改 evalscope 的配置或使用自定义的评估脚本。

## 更新日志

### v2.0 (当前版本)
- ✅ 完善的服务管理功能
- ✅ 支持多数据集和评估套件
- ✅ 增强的错误处理和日志
- ✅ 自动生成评估报告
- ✅ 配置文件支持
- ✅ Python 增强脚本

### v1.0 (原始版本)
- ✅ 基本的 VLLM 服务启动
- ✅ 简单的 evalscope 评估

---

如有问题或建议，请查看日志文件或联系技术支持。