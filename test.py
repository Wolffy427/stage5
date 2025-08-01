import csv
import traceback
import time
import json
from locust import HttpUser, task, between, events
import logging
from threading import Lock

# 全局统计变量
stats_lock = Lock()
request_stats = {
    'total_requests': 0,
    'successful_requests': 0,
    'failed_requests': 0,
    'total_response_time': 0,
    'min_response_time': float('inf'),
    'max_response_time': 0,
    'response_times': []
}

def init_logging_config():
    level = logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    _logger = logging.getLogger("VLLM_LOAD_TEST")
    _logger.setLevel(level)
    return _logger

logger = init_logging_config()

# 配置参数
BASE_URL = "http://localhost:8000"
INPUT_FILE = 'data/content_1.csv'

# 读取测试数据
test_data = []
try:
    with open(INPUT_FILE, mode='r', encoding='utf-8') as infile:
        reader = csv.reader(infile)
        next(reader)  # 跳过表头
        test_data = [row[1] for row in reader if len(row) > 1]
    logger.info(f"加载了 {len(test_data)} 条测试数据")
except FileNotFoundError:
    logger.error(f"测试数据文件 {INPUT_FILE} 不存在")
    test_data = ["这是一个默认的测试问题，请回答。"]

class VLLMLoadTest(HttpUser):
    wait_time = between(1, 3)  # 用户请求间隔时间
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.data_index = 0
    
    def get_next_query(self):
        """获取下一个测试查询"""
        if not test_data:
            return "默认测试问题"
        
        query = test_data[self.data_index % len(test_data)]
        self.data_index += 1
        return query
    
    def create_chat_completion_request(self, query):
        """创建聊天完成请求数据"""
        return {
            "model": "llm-model",
            "messages": [
                {
                    "role": "user",
                    "content": query
                }
            ],
            "max_tokens": 512,
            "temperature": 0.7,
            "stream": False
        }
    
    def update_stats(self, response_time, success):
        """更新统计信息"""
        with stats_lock:
            stats = request_stats
            stats['total_requests'] += 1
            stats['total_response_time'] += response_time
            stats['response_times'].append(response_time)
            
            if success:
                stats['successful_requests'] += 1
            else:
                stats['failed_requests'] += 1
            
            stats['min_response_time'] = min(stats['min_response_time'], response_time)
            stats['max_response_time'] = max(stats['max_response_time'], response_time)
    
    @task
    def chat_completion(self):
        """聊天完成任务"""
        query = self.get_next_query()
        data = self.create_chat_completion_request(query)
        
        start_time = time.time()
        success = False
        
        try:
            with self.client.post(
                "/v1/chat/completions",
                json=data,
                timeout=120,
                catch_response=True
            ) as response:
                response_time = (time.time() - start_time) * 1000  # 转换为毫秒
                
                if response.status_code == 200:
                    try:
                        result = response.json()
                        if 'choices' in result and len(result['choices']) > 0:
                            success = True
                            response.success()
                            logger.info(f"请求成功 - 状态码: {response.status_code}, 响应时间: {response_time:.2f}ms")
                        else:
                            response.failure("响应格式错误")
                            logger.error(f"响应格式错误: {response.text}")
                    except json.JSONDecodeError:
                        response.failure("JSON解析失败")
                        logger.error(f"JSON解析失败: {response.text}")
                else:
                    response.failure(f"HTTP {response.status_code}")
                    logger.error(f"请求失败 - 状态码: {response.status_code}, 响应: {response.text}")
                
                self.update_stats(response_time, success)
                
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            self.update_stats(response_time, False)
            logger.error(f"请求异常: {traceback.format_exc()}")

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """测试结束时打印统计信息"""
    stats = request_stats
    
    if stats['total_requests'] == 0:
        logger.info("没有执行任何请求")
        return
    
    # 计算统计指标
    avg_response_time = stats['total_response_time'] / stats['total_requests']
    success_rate = (stats['successful_requests'] / stats['total_requests']) * 100
    
    # 计算百分位数
    response_times = sorted(stats['response_times'])
    p50_index = int(len(response_times) * 0.5)
    p95_index = int(len(response_times) * 0.95)
    p99_index = int(len(response_times) * 0.99)
    
    p50 = response_times[p50_index] if p50_index < len(response_times) else 0
    p95 = response_times[p95_index] if p95_index < len(response_times) else 0
    p99 = response_times[p99_index] if p99_index < len(response_times) else 0
    
    # 计算吞吐量 (RPS)
    test_duration = environment.runner.stats.total.get_current_response_time_percentile(1.0) / 1000
    if test_duration > 0:
        throughput = stats['total_requests'] / test_duration
    else:
        throughput = 0
    
    logger.info("\n" + "="*60)
    logger.info("VLLM 压测结果统计")
    logger.info("="*60)
    logger.info(f"总请求数: {stats['total_requests']}")
    logger.info(f"成功请求数: {stats['successful_requests']}")
    logger.info(f"失败请求数: {stats['failed_requests']}")
    logger.info(f"成功率: {success_rate:.2f}%")
    logger.info(f"平均响应时间: {avg_response_time:.2f}ms")
    logger.info(f"最小响应时间: {stats['min_response_time']:.2f}ms")
    logger.info(f"最大响应时间: {stats['max_response_time']:.2f}ms")
    logger.info(f"P50响应时间: {p50:.2f}ms")
    logger.info(f"P95响应时间: {p95:.2f}ms")
    logger.info(f"P99响应时间: {p99:.2f}ms")
    logger.info(f"吞吐量: {throughput:.2f} RPS")
    logger.info("="*60)

if __name__ == "__main__":
    # 单独运行时的测试代码
    import sys
    print("这是VLLM压测脚本，请使用locust命令运行:")
    print("locust -f test.py --host=http://localhost:8000")