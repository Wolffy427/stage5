#!/bin/bash

# EvalScope 评估脚本
# 用于启动VLLM服务并运行模型评估

# 默认配置参数
MODEL_PATH="${MODEL_PATH:-/root/autodl-tmp/stage5/models/Qwen/Qwen2-7B-Instruct}"
SERVE_HOST="${SERVE_HOST:-0.0.0.0}"
SERVE_PORT="${SERVE_PORT:-8801}"
MODEL_NAME="${MODEL_NAME:-qwen2.5}"
DATASETS="${DATASETS:-gsm8k}"
LIMIT="${LIMIT:-10}"
WORK_DIR="${WORK_DIR:-/root/autodl-tmp/stage5/evalscope}"
TIMEOUT="${TIMEOUT:-300}"
MAX_TOKENS="${MAX_TOKENS:-2048}"
TEMPERATURE="${TEMPERATURE:-0.0}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.8}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

# PID文件路径
PID_FILE=".vllm_evalscope.pid"
LOG_DIR="logs"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 显示使用帮助
show_usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  start       启动VLLM服务并运行评估"
    echo "  serve       仅启动VLLM服务"
    echo "  eval        仅运行评估（需要服务已启动）"
    echo "  stop        停止VLLM服务"
    echo "  status      查看服务状态"
    echo "  logs        查看服务日志"
    echo "  clean       清理旧的评估结果"
    echo ""
    echo "环境变量:"
    echo "  MODEL_PATH              模型路径 (默认: $MODEL_PATH)"
    echo "  SERVE_HOST              服务主机 (默认: $SERVE_HOST)"
    echo "  SERVE_PORT              服务端口 (默认: $SERVE_PORT)"
    echo "  MODEL_NAME              模型名称 (默认: $MODEL_NAME)"
    echo "  DATASETS                评估数据集 (默认: $DATASETS)"
    echo "  LIMIT                   评估样本数量 (默认: $LIMIT)"
    echo "  WORK_DIR                工作目录 (默认: $WORK_DIR)"
    echo "  TIMEOUT                 超时时间(秒) (默认: $TIMEOUT)"
    echo "  MAX_TOKENS              最大生成token数 (默认: $MAX_TOKENS)"
    echo "  TEMPERATURE             生成温度 (默认: $TEMPERATURE)"
    echo "  GPU_MEMORY_UTILIZATION  GPU内存利用率 (默认: $GPU_MEMORY_UTILIZATION)"
    echo "  MAX_MODEL_LEN           最大模型长度 (默认: $MAX_MODEL_LEN)"
    echo ""
    echo "示例:"
    echo "  $0 start                    # 启动服务并运行评估"
    echo "  DATASETS=mmlu $0 start      # 使用MMLU数据集评估"
    echo "  LIMIT=50 $0 eval           # 评估50个样本"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查vllm
    if ! command -v vllm &> /dev/null; then
        log_error "vllm未安装，请先安装: pip install vllm"
        return 1
    fi
    
    # 检查evalscope
    if ! python -c "import evalscope" &> /dev/null; then
        log_error "evalscope未安装，请先安装: pip install evalscope"
        return 1
    fi
    
    # 检查模型路径
    if [ ! -d "$MODEL_PATH" ]; then
        log_error "模型路径不存在: $MODEL_PATH"
        return 1
    fi
    
    log_info "依赖检查通过"
    return 0
}

# 检查服务状态
check_service_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# 等待服务可用
wait_for_service() {
    local max_attempts=30
    local attempt=1
    
    log_info "等待服务启动..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$SERVE_PORT/health" > /dev/null 2>&1; then
            log_info "服务已就绪"
            return 0
        fi
        
        log_debug "等待服务启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log_error "服务启动超时"
    return 1
}

# 启动VLLM服务
start_vllm_service() {
    if check_service_status; then
        log_warn "VLLM服务已在运行中，PID: $(cat $PID_FILE)"
        return 0
    fi
    
    log_info "启动VLLM服务..."
    log_info "模型路径: $MODEL_PATH"
    log_info "服务地址: $SERVE_HOST:$SERVE_PORT"
    log_info "模型名称: $MODEL_NAME"
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 启动服务
    nohup vllm serve "$MODEL_PATH" \
        --host "$SERVE_HOST" \
        --port "$SERVE_PORT" \
        --served-model-name "$MODEL_NAME" \
        --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
        --max-model-len "$MAX_MODEL_LEN" \
        --trust-remote-code \
        > "$LOG_DIR/vllm_evalscope.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
    log_info "服务已启动，PID: $pid"
    
    # 等待服务可用
    if wait_for_service; then
        log_info "VLLM服务启动成功！"
        log_info "服务地址: http://localhost:$SERVE_PORT"
        return 0
    else
        log_error "服务启动失败，请检查日志: $LOG_DIR/vllm_evalscope.log"
        return 1
    fi
}

# 运行评估
run_evaluation() {
    log_info "开始运行评估..."
    
    # 检查服务是否运行
    if ! check_service_status; then
        log_error "VLLM服务未运行，请先启动服务"
        return 1
    fi
    
    # 检查服务健康状态
    if ! curl -s "http://localhost:$SERVE_PORT/health" > /dev/null 2>&1; then
        log_error "VLLM服务不健康，请检查服务状态"
        return 1
    fi
    
    # 创建工作目录
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local eval_work_dir="$WORK_DIR/$timestamp"
    mkdir -p "$eval_work_dir"
    
    log_info "评估配置:"
    log_info "  模型: $MODEL_NAME"
    log_info "  数据集: $DATASETS"
    log_info "  样本数量: $LIMIT"
    log_info "  工作目录: $eval_work_dir"
    log_info "  API地址: http://127.0.0.1:$SERVE_PORT/v1"
    log_info "  最大tokens: $MAX_TOKENS"
    log_info "  温度: $TEMPERATURE"
    
    # 运行评估
    evalscope eval \
        --model "$MODEL_NAME" \
        --api-url "http://127.0.0.1:$SERVE_PORT/v1" \
        --api-key EMPTY \
        --eval-type service \
        --datasets "$DATASETS" \
        --limit "$LIMIT" \
        --work-dir "$eval_work_dir" \
        --timeout "$TIMEOUT" \
        --generation-config "{\"max_tokens\": $MAX_TOKENS, \"temperature\": $TEMPERATURE}"
    
    local eval_status=$?
    
    if [ $eval_status -eq 0 ]; then
        log_info "评估完成！"
        log_info "结果保存在: $eval_work_dir"
        
        # 显示结果摘要
        if [ -f "$eval_work_dir/logs/eval_log.log" ]; then
            log_info "评估日志:"
            tail -20 "$eval_work_dir/logs/eval_log.log"
        fi
    else
        log_error "评估失败，退出码: $eval_status"
        log_error "请检查日志: $eval_work_dir/logs/eval_log.log"
        return 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止VLLM服务..."
    
    if ! check_service_status; then
        log_warn "服务未运行"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log_info "停止服务，PID: $pid"
    
    # 尝试优雅停止
    kill "$pid" 2>/dev/null
    sleep 5
    
    # 检查是否已停止
    if ps -p "$pid" > /dev/null 2>&1; then
        log_warn "强制停止服务..."
        kill -9 "$pid" 2>/dev/null
        sleep 2
    fi
    
    # 清理PID文件
    rm -f "$PID_FILE"
    
    log_info "VLLM服务已停止"
}

# 查看服务状态
show_status() {
    echo "======================================"
    echo "VLLM EvalScope 服务状态"
    echo "======================================"
    
    if check_service_status; then
        local pid=$(cat "$PID_FILE")
        echo "状态: 运行中"
        echo "PID: $pid"
        echo "端口: $SERVE_PORT"
        
        # 检查服务健康状态
        if curl -s "http://localhost:$SERVE_PORT/health" > /dev/null 2>&1; then
            echo "健康状态: 正常"
        else
            echo "健康状态: 异常"
        fi
        
        # 显示模型信息
        if curl -s "http://localhost:$SERVE_PORT/v1/models" > /dev/null 2>&1; then
            echo "模型服务: 可用"
        else
            echo "模型服务: 不可用"
        fi
    else
        echo "状态: 未运行"
    fi
    
    echo "配置信息:"
    echo "  模型路径: $MODEL_PATH"
    echo "  模型名称: $MODEL_NAME"
    echo "  服务地址: $SERVE_HOST:$SERVE_PORT"
    echo "  工作目录: $WORK_DIR"
}

# 查看日志
show_logs() {
    if [ -f "$LOG_DIR/vllm_evalscope.log" ]; then
        log_info "显示VLLM服务日志 (按Ctrl+C退出):"
        tail -f "$LOG_DIR/vllm_evalscope.log"
    else
        log_error "日志文件不存在: $LOG_DIR/vllm_evalscope.log"
    fi
}

# 清理旧结果
clean_results() {
    log_info "清理旧的评估结果..."
    
    if [ -d "$WORK_DIR" ]; then
        # 保留最近的5个结果
        local keep_count=5
        local result_dirs=$(ls -1t "$WORK_DIR" 2>/dev/null | tail -n +$((keep_count + 1)))
        
        if [ -n "$result_dirs" ]; then
            echo "$result_dirs" | while read -r dir; do
                if [ -d "$WORK_DIR/$dir" ]; then
                    log_info "删除旧结果: $WORK_DIR/$dir"
                    rm -rf "$WORK_DIR/$dir"
                fi
            done
        else
            log_info "没有需要清理的旧结果"
        fi
    else
        log_info "工作目录不存在: $WORK_DIR"
    fi
}

# 主程序
main() {
    # 创建必要的目录
    mkdir -p "$LOG_DIR"
    mkdir -p "$WORK_DIR"
    
    case "$1" in
        "start")
            if ! check_dependencies; then
                exit 1
            fi
            if start_vllm_service; then
                sleep 2  # 等待服务完全启动
                run_evaluation
            fi
            ;;
        "serve")
            if ! check_dependencies; then
                exit 1
            fi
            start_vllm_service
            ;;
        "eval")
            run_evaluation
            ;;
        "stop")
            stop_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "clean")
            clean_results
            ;;
        "")
            log_error "请指定命令"
            show_usage
            exit 1
            ;;
        *)
            log_error "未知命令 '$1'"
            show_usage
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"