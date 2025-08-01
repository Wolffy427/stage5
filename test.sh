#!/bin/bash

# VLLM压测管理脚本
# 支持部署、测试、卸载等操作

# 默认配置参数
HOST="${HOST:-http://localhost:8000}"
SERVE_HOST="${SERVE_HOST:-0.0.0.0}"
SERVE_PORT="${SERVE_PORT:-8000}"
USERS="${USERS:-10}"                    # 并发用户数
SPAWN_RATE="${SPAWN_RATE:-2}"           # 每秒启动用户数
RUN_TIME="${RUN_TIME:-60s}"             # 运行时间
LOGLEVEL="${LOGLEVEL:-INFO}"            # 日志级别
WEB_PORT="${WEB_PORT:-8089}"            # Web UI端口
MODEL_PATH="${MODEL_PATH:-/root/autodl-tmp/stage5/models/Qwen/Qwen2-7B-Instruct}"

# PID文件路径
PID_FILE=".vllm_serve.pid"

# 显示使用帮助
show_usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  deploy      部署VLLM服务"
    echo "  test        运行压测 (默认Web UI模式)"
    echo "  test -h     运行压测 (无头模式)"
    echo "  undeploy    停止并卸载VLLM服务"
    echo "  status      查看服务状态"
    echo "  logs        查看服务日志"
    echo ""
    echo "环境变量:"
    echo "  MODEL_PATH     模型路径 (默认: $MODEL_PATH)"
    echo "  SERVE_HOST     服务主机 (默认: $SERVE_HOST)"
    echo "  SERVE_PORT     服务端口 (默认: $SERVE_PORT)"
    echo "  USERS          并发用户数 (默认: $USERS)"
    echo "  SPAWN_RATE     用户启动速率 (默认: $SPAWN_RATE)"
    echo "  RUN_TIME       运行时间 (默认: $RUN_TIME)"
    echo "  WEB_PORT       Web UI端口 (默认: $WEB_PORT)"
    echo ""
    echo "示例:"
    echo "  $0 deploy                    # 部署服务"
    echo "  $0 test                      # Web UI模式压测"
    echo "  $0 test -h                   # 无头模式压测"
    echo "  USERS=50 $0 test -h          # 自定义参数压测"
    echo "  $0 undeploy                  # 卸载服务"
}

# 检查服务是否运行
check_service_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # 服务正在运行
        else
            rm -f "$PID_FILE"  # 清理无效的PID文件
            return 1  # 服务未运行
        fi
    else
        return 1  # 服务未运行
    fi
}

# 等待服务启动
wait_for_service() {
    echo "等待服务启动..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "http://localhost:$SERVE_PORT/health" > /dev/null 2>&1; then
            echo "服务已启动并可访问"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
        echo "等待中... ($attempt/$max_attempts)"
    done
    
    echo "服务启动超时"
    return 1
}

# 部署VLLM服务
deploy_service() {
    echo "======================================"
    echo "部署VLLM服务"
    echo "======================================"
    
    if check_service_status; then
        echo "服务已在运行中，PID: $(cat $PID_FILE)"
        return 0
    fi
    
    echo "模型路径: $MODEL_PATH"
    echo "服务地址: $SERVE_HOST:$SERVE_PORT"
    
    # 检查模型路径是否存在
    if [ ! -d "$MODEL_PATH" ]; then
        echo "错误: 模型路径不存在: $MODEL_PATH"
        return 1
    fi
    
    # 启动服务
    echo "启动VLLM服务..."
    nohup ./serve.sh > logs/vllm_serve.log 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    echo "服务已启动，PID: $pid"
    
    # 等待服务可用
    if wait_for_service; then
        echo "VLLM服务部署成功！"
        echo "服务地址: http://localhost:$SERVE_PORT"
        return 0
    else
        echo "服务启动失败，请检查日志: logs/vllm_serve.log"
        return 1
    fi
}

# 运行压测
run_test() {
    echo "======================================"
    echo "VLLM 压测配置"
    echo "======================================"
    echo "目标服务: $HOST"
    echo "并发用户数: $USERS"
    echo "用户启动速率: $SPAWN_RATE/秒"
    echo "运行时间: $RUN_TIME"
    echo "Web UI端口: $WEB_PORT"
    echo "日志级别: $LOGLEVEL"
    echo "======================================"
    
    # 检查服务是否运行
    if ! check_service_status; then
        echo "警告: VLLM服务未运行，尝试自动部署..."
        if ! deploy_service; then
            echo "错误: 无法启动VLLM服务"
            return 1
        fi
    fi
    
    # 检查locust是否安装
    if ! command -v locust &> /dev/null; then
        echo "错误: locust未安装，正在尝试安装..."
        pip install locust
        if [ $? -ne 0 ]; then
            echo "locust安装失败，请手动安装: pip install locust"
            return 1
        fi
    fi
    
    # 检查测试文件是否存在
    if [ ! -f "test.py" ]; then
        echo "错误: test.py文件不存在"
        return 1
    fi
    
    # 检查测试数据文件是否存在
    if [ ! -f "data/content_1.csv" ]; then
        echo "警告: 测试数据文件 data/content_1.csv 不存在，将使用默认数据"
    fi
    
    # 创建日志目录
    mkdir -p logs
    
    # 获取当前时间戳
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="logs/locust_test_${timestamp}.log"
    
    echo "开始压测..."
    echo "日志文件: $log_file"
    
    # 启动locust压测
    if [ "$1" = "--headless" ] || [ "$1" = "-h" ]; then
        echo "以无头模式运行压测..."
        locust -f test.py \
            --host="$HOST" \
            --users="$USERS" \
            --spawn-rate="$SPAWN_RATE" \
            --run-time="$RUN_TIME" \
            --headless \
            --loglevel="$LOGLEVEL" \
            --logfile="$log_file" \
            --html="logs/report_${timestamp}.html" \
            --csv="logs/stats_${timestamp}"
        
        echo ""
        echo "压测完成！"
        echo "日志文件: $log_file"
        echo "HTML报告: logs/report_${timestamp}.html"
        echo "CSV统计: logs/stats_${timestamp}_stats.csv"
    else
        echo "以Web UI模式运行压测..."
        echo "Web UI: http://localhost:$WEB_PORT"
        echo "请在浏览器中访问上述地址来控制测试"
        echo "按 Ctrl+C 停止测试"
        locust -f test.py \
            --host="$HOST" \
            --web-port="$WEB_PORT" \
            --loglevel="$LOGLEVEL" \
            --logfile="$log_file"
    fi
}

# 卸载服务
undeploy_service() {
    echo "======================================"
    echo "卸载VLLM服务"
    echo "======================================"
    
    if ! check_service_status; then
        echo "服务未运行"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    echo "停止服务，PID: $pid"
    
    # 尝试优雅停止
    kill "$pid" 2>/dev/null
    sleep 5
    
    # 检查是否已停止
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "强制停止服务..."
        kill -9 "$pid" 2>/dev/null
        sleep 2
    fi
    
    # 清理PID文件
    rm -f "$PID_FILE"
    
    echo "VLLM服务已停止"
}

# 查看服务状态
show_status() {
    echo "======================================"
    echo "VLLM服务状态"
    echo "======================================"
    
    if check_service_status; then
        local pid=$(cat "$PID_FILE")
        echo "状态: 运行中"
        echo "PID: $pid"
        echo "服务地址: http://localhost:$SERVE_PORT"
        
        # 检查服务健康状态
        if curl -s "http://localhost:$SERVE_PORT/health" > /dev/null 2>&1; then
            echo "健康状态: 正常"
        else
            echo "健康状态: 异常"
        fi
    else
        echo "状态: 未运行"
    fi
}

# 查看服务日志
show_logs() {
    echo "======================================"
    echo "VLLM服务日志"
    echo "======================================"
    
    if [ -f "logs/vllm_serve.log" ]; then
        tail -f logs/vllm_serve.log
    else
        echo "日志文件不存在: logs/vllm_serve.log"
    fi
}

# 主程序
main() {
    # 创建日志目录
    mkdir -p logs
    
    case "$1" in
        "deploy")
            deploy_service
            ;;
        "test")
            shift
            run_test "$@"
            ;;
        "undeploy")
            undeploy_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "")
            echo "错误: 请指定命令"
            show_usage
            exit 1
            ;;
        *)
            echo "错误: 未知命令 '$1'"
            show_usage
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"