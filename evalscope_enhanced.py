#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EvalScope 增强评估脚本
支持配置文件、多数据集评估、结果分析等功能
"""

import os
import sys
import yaml
import json
import argparse
import logging
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('EvalScope')

class EvalScopeRunner:
    """EvalScope 评估运行器"""
    
    def __init__(self, config_path: str = "evalscope_config.yaml"):
        self.config_path = config_path
        self.config = self.load_config()
        self.work_dir = Path(self.config['evaluation']['work_dir'])
        self.setup_logging()
        
    def load_config(self) -> Dict[str, Any]:
        """加载配置文件"""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
            logger.info(f"配置文件加载成功: {self.config_path}")
            return config
        except FileNotFoundError:
            logger.error(f"配置文件不存在: {self.config_path}")
            sys.exit(1)
        except yaml.YAMLError as e:
            logger.error(f"配置文件格式错误: {e}")
            sys.exit(1)
            
    def setup_logging(self):
        """设置日志"""
        log_config = self.config.get('logging', {})
        level = getattr(logging, log_config.get('level', 'INFO'))
        logging.getLogger().setLevel(level)
        
    def check_dependencies(self) -> bool:
        """检查依赖"""
        logger.info("检查依赖...")
        
        # 检查 vllm
        try:
            subprocess.run(['vllm', '--version'], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            logger.error("vllm 未安装或不可用")
            return False
            
        # 检查 evalscope
        try:
            import evalscope
            logger.info(f"evalscope 版本: {evalscope.__version__}")
        except ImportError:
            logger.error("evalscope 未安装")
            return False
            
        # 检查模型路径
        model_path = Path(self.config['model']['path'])
        if not model_path.exists():
            logger.error(f"模型路径不存在: {model_path}")
            return False
            
        logger.info("依赖检查通过")
        return True
        
    def start_vllm_service(self) -> bool:
        """启动 VLLM 服务"""
        service_config = self.config['service']
        model_config = self.config['model']
        
        cmd = [
            'vllm', 'serve', model_config['path'],
            '--host', service_config['host'],
            '--port', str(service_config['port']),
            '--served-model-name', service_config['model_name'],
            '--gpu-memory-utilization', str(service_config['gpu_memory_utilization']),
            '--max-model-len', str(service_config['max_model_len'])
        ]
        
        if service_config.get('trust_remote_code', True):
            cmd.append('--trust-remote-code')
            
        logger.info(f"启动 VLLM 服务: {' '.join(cmd)}")
        
        # 创建日志目录
        log_dir = Path('logs')
        log_dir.mkdir(exist_ok=True)
        
        # 启动服务
        with open(log_dir / 'vllm_service.log', 'w') as f:
            process = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
            
        # 保存 PID
        with open('.vllm_service.pid', 'w') as f:
            f.write(str(process.pid))
            
        logger.info(f"VLLM 服务已启动，PID: {process.pid}")
        
        # 等待服务就绪
        return self.wait_for_service()
        
    def wait_for_service(self, max_attempts: int = 30) -> bool:
        """等待服务就绪"""
        import requests
        
        service_config = self.config['service']
        health_url = f"http://localhost:{service_config['port']}/health"
        
        logger.info("等待服务就绪...")
        
        for attempt in range(1, max_attempts + 1):
            try:
                response = requests.get(health_url, timeout=5)
                if response.status_code == 200:
                    logger.info("服务已就绪")
                    return True
            except requests.RequestException:
                pass
                
            logger.debug(f"等待服务启动... ({attempt}/{max_attempts})")
            time.sleep(2)
            
        logger.error("服务启动超时")
        return False
        
    def run_evaluation(self, datasets: List[str], limit: Optional[int] = None, 
                      suite: Optional[str] = None) -> bool:
        """运行评估"""
        logger.info("开始运行评估...")
        
        # 处理评估套件
        if suite:
            if suite not in self.config['suites']:
                logger.error(f"未知的评估套件: {suite}")
                return False
            suite_config = self.config['suites'][suite]
            datasets = suite_config['datasets']
            limit = limit or suite_config['limit']
            logger.info(f"使用评估套件: {suite} - {suite_config['description']}")
            
        # 使用默认数据集
        if not datasets:
            datasets = ['gsm8k']
            
        # 创建工作目录
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        eval_work_dir = self.work_dir / timestamp
        eval_work_dir.mkdir(parents=True, exist_ok=True)
        
        # 保存评估配置
        eval_config = {
            'timestamp': timestamp,
            'datasets': datasets,
            'limit': limit or self.config['evaluation']['limit'],
            'model': self.config['model'],
            'service': self.config['service'],
            'generation': self.config['generation']
        }
        
        with open(eval_work_dir / 'eval_config.json', 'w', encoding='utf-8') as f:
            json.dump(eval_config, f, indent=2, ensure_ascii=False)
            
        # 运行评估
        success = True
        results = {}
        
        for dataset in datasets:
            logger.info(f"评估数据集: {dataset}")
            
            # 获取数据集配置
            dataset_config = self.config['evaluation']['datasets'].get(dataset, {})
            dataset_limit = limit or dataset_config.get('limit', self.config['evaluation']['limit'])
            
            # 构建评估命令
            cmd = self.build_eval_command(dataset, dataset_limit, eval_work_dir / dataset)
            
            # 运行评估
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
                if result.returncode == 0:
                    logger.info(f"数据集 {dataset} 评估完成")
                    results[dataset] = {'status': 'success', 'output': result.stdout}
                else:
                    logger.error(f"数据集 {dataset} 评估失败: {result.stderr}")
                    results[dataset] = {'status': 'failed', 'error': result.stderr}
                    success = False
            except subprocess.TimeoutExpired:
                logger.error(f"数据集 {dataset} 评估超时")
                results[dataset] = {'status': 'timeout'}
                success = False
            except Exception as e:
                logger.error(f"数据集 {dataset} 评估异常: {e}")
                results[dataset] = {'status': 'error', 'error': str(e)}
                success = False
                
        # 保存结果摘要
        with open(eval_work_dir / 'results_summary.json', 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
            
        if success:
            logger.info(f"评估完成！结果保存在: {eval_work_dir}")
            self.generate_report(eval_work_dir, results)
        else:
            logger.error("部分评估失败，请检查日志")
            
        return success
        
    def build_eval_command(self, dataset: str, limit: int, work_dir: Path) -> List[str]:
        """构建评估命令"""
        service_config = self.config['service']
        generation_config = self.config['generation']
        
        cmd = [
            'evalscope', 'eval',
            '--model', service_config['model_name'],
            '--api-url', f"http://127.0.0.1:{service_config['port']}/v1",
            '--api-key', 'EMPTY',
            '--eval-type', 'service',
            '--datasets', dataset,
            '--limit', str(limit),
            '--work-dir', str(work_dir),
            '--timeout', str(service_config['timeout']),
            '--generation-config', json.dumps(generation_config)
        ]
        
        return cmd
        
    def generate_report(self, work_dir: Path, results: Dict[str, Any]):
        """生成评估报告"""
        logger.info("生成评估报告...")
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'work_dir': str(work_dir),
            'summary': {
                'total_datasets': len(results),
                'successful': sum(1 for r in results.values() if r['status'] == 'success'),
                'failed': sum(1 for r in results.values() if r['status'] != 'success')
            },
            'results': results
        }
        
        # 保存 JSON 报告
        with open(work_dir / 'evaluation_report.json', 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
            
        # 生成简单的文本报告
        with open(work_dir / 'evaluation_report.txt', 'w', encoding='utf-8') as f:
            f.write("EvalScope 评估报告\n")
            f.write("=" * 50 + "\n")
            f.write(f"评估时间: {report['timestamp']}\n")
            f.write(f"工作目录: {report['work_dir']}\n")
            f.write(f"总数据集: {report['summary']['total_datasets']}\n")
            f.write(f"成功: {report['summary']['successful']}\n")
            f.write(f"失败: {report['summary']['failed']}\n")
            f.write("\n详细结果:\n")
            
            for dataset, result in results.items():
                f.write(f"\n数据集: {dataset}\n")
                f.write(f"状态: {result['status']}\n")
                if result['status'] != 'success':
                    f.write(f"错误: {result.get('error', 'N/A')}\n")
                    
        logger.info(f"报告已生成: {work_dir}/evaluation_report.json")
        
    def stop_service(self):
        """停止服务"""
        pid_file = Path('.vllm_service.pid')
        if not pid_file.exists():
            logger.info("服务未运行")
            return
            
        try:
            with open(pid_file, 'r') as f:
                pid = int(f.read().strip())
                
            import signal
            os.kill(pid, signal.SIGTERM)
            logger.info(f"服务已停止，PID: {pid}")
            
            pid_file.unlink()
        except (ValueError, ProcessLookupError, FileNotFoundError):
            logger.warning("无法停止服务或服务已停止")
            if pid_file.exists():
                pid_file.unlink()
                
    def list_suites(self):
        """列出可用的评估套件"""
        print("可用的评估套件:")
        print("=" * 50)
        
        for name, config in self.config['suites'].items():
            print(f"名称: {name}")
            print(f"描述: {config['description']}")
            print(f"数据集: {', '.join(config['datasets'])}")
            print(f"样本数: {config['limit']}")
            print("-" * 30)
            
    def list_datasets(self):
        """列出可用的数据集"""
        print("可用的数据集:")
        print("=" * 50)
        
        for name, config in self.config['evaluation']['datasets'].items():
            print(f"名称: {name}")
            print(f"描述: {config['description']}")
            print(f"默认样本数: {config['limit']}")
            print("-" * 30)

def main():
    parser = argparse.ArgumentParser(description='EvalScope 增强评估工具')
    parser.add_argument('--config', '-c', default='evalscope_config.yaml',
                       help='配置文件路径')
    
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # start 命令
    start_parser = subparsers.add_parser('start', help='启动服务并运行评估')
    start_parser.add_argument('--datasets', '-d', nargs='+', 
                             help='要评估的数据集')
    start_parser.add_argument('--limit', '-l', type=int,
                             help='每个数据集的样本数量')
    start_parser.add_argument('--suite', '-s',
                             help='使用预设的评估套件')
    
    # serve 命令
    subparsers.add_parser('serve', help='仅启动服务')
    
    # eval 命令
    eval_parser = subparsers.add_parser('eval', help='仅运行评估')
    eval_parser.add_argument('--datasets', '-d', nargs='+',
                            help='要评估的数据集')
    eval_parser.add_argument('--limit', '-l', type=int,
                            help='每个数据集的样本数量')
    eval_parser.add_argument('--suite', '-s',
                            help='使用预设的评估套件')
    
    # stop 命令
    subparsers.add_parser('stop', help='停止服务')
    
    # list 命令
    list_parser = subparsers.add_parser('list', help='列出可用资源')
    list_parser.add_argument('type', choices=['suites', 'datasets'],
                            help='列出类型')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    runner = EvalScopeRunner(args.config)
    
    if args.command == 'start':
        if not runner.check_dependencies():
            sys.exit(1)
        if runner.start_vllm_service():
            time.sleep(2)  # 等待服务完全启动
            runner.run_evaluation(args.datasets or [], args.limit, args.suite)
    elif args.command == 'serve':
        if not runner.check_dependencies():
            sys.exit(1)
        runner.start_vllm_service()
    elif args.command == 'eval':
        runner.run_evaluation(args.datasets or [], args.limit, args.suite)
    elif args.command == 'stop':
        runner.stop_service()
    elif args.command == 'list':
        if args.type == 'suites':
            runner.list_suites()
        elif args.type == 'datasets':
            runner.list_datasets()

if __name__ == '__main__':
    main()