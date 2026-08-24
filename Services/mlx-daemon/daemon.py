#!/usr/bin/env python3
"""Fusion Studio MLX 守护进程 — fusion-mlx 推理服务常驻管理

负责:
  1. 启动/停止/重启 fusion-mlx HTTP 推理服务
  2. 健康检查（轮询 /v1/models）
  3. 硬件监控（统一内存、GPU 占用、推理耗时）
  4. 通过 Unix Socket JSON-RPC 与主程序通信
"""

import os
import sys
import json
import signal
import time
import socket
import threading
import subprocess
import logging
from pathlib import Path
from typing import Optional, Dict, Any
from dataclasses import dataclass, asdict
from http.server import HTTPServer, BaseHTTPRequestHandler

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("mlx-daemon")


# ─── 配置 ───────────────────────────────────────────────────────────

@dataclass
class MLXConfig:
    mlx_path: str = str(Path.home() / "claude-home" / "fusion-mlx")
    host: str = "localhost"
    port: int = 11434
    model: str = ""  # 默认模型，为空则使用 fusion-mlx 默认
    quant: str = "4bit"
    max_memory_gb: int = 16
    daemon: bool = True


# ─── MLX 进程管理器 ─────────────────────────────────────────────────

class MLXProcessManager:
    """管理 fusion-mlx 推理服务进程"""

    def __init__(self, config: MLXConfig):
        self.config = config
        self.process: Optional[subprocess.Popen] = None
        self._stop_event = threading.Event()

    @property
    def is_running(self) -> bool:
        if self.process is None:
            return False
        return self.process.poll() is None

    def start(self) -> bool:
        """启动 fusion-mlx 服务"""
        if self.is_running:
            logger.warning("fusion-mlx 已在运行中")
            return True

        mlx_script = Path(self.config.mlx_path) / "serve.py"
        if not mlx_script.exists():
            mlx_script = Path(self.config.mlx_path) / "fusion_mlx" / "serve.py"
        if not mlx_script.exists():
            logger.error(f"fusion-mlx 未找到: {self.config.mlx_path}")
            return False

        cmd = [
            sys.executable, str(mlx_script),
            "--host", self.config.host,
            "--port", str(self.config.port),
        ]
        if self.config.model:
            cmd.extend(["--model", self.config.model])
        if self.config.daemon:
            cmd.append("--daemon")

        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            logger.info(f"fusion-mlx 已启动 (PID: {self.process.pid})")
            # 等待服务就绪
            self._wait_for_ready()
            return True
        except Exception as e:
            logger.error(f"启动 fusion-mlx 失败: {e}")
            return False

    def stop(self) -> bool:
        """停止 fusion-mlx 服务"""
        if self.process is None:
            return True

        try:
            self.process.terminate()
            self.process.wait(timeout=10)
            logger.info("fusion-mlx 已停止")
        except subprocess.TimeoutExpired:
            self.process.kill()
            logger.warning("fusion-mlx 强制终止")
        except Exception as e:
            logger.error(f"停止 fusion-mlx 失败: {e}")
            return False
        finally:
            self.process = None
        return True

    def restart(self) -> bool:
        """重启 fusion-mlx 服务"""
        self.stop()
        time.sleep(1)
        return self.start()

    def health_check(self) -> Dict[str, Any]:
        """检查 fusion-mlx 服务健康状态"""
        import urllib.request
        import urllib.error

        try:
            url = f"http://{self.config.host}:{self.config.port}/v1/models"
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode())
                return {
                    "status": "healthy",
                    "http_code": resp.status,
                    "models": data.get("data", []),
                }
        except urllib.error.HTTPError as e:
            return {
                "status": "degraded",
                "http_code": e.code,
                "error": str(e.reason),
            }
        except Exception as e:
            return {
                "status": "unhealthy",
                "error": str(e),
            }

    def _wait_for_ready(self, timeout: int = 30):
        """等待 fusion-mlx HTTP 服务就绪"""
        import urllib.request
        import urllib.error

        start = time.time()
        while time.time() - start < timeout:
            try:
                url = f"http://{self.config.host}:{self.config.port}/v1/models"
                req = urllib.request.Request(url, method="GET")
                with urllib.request.urlopen(req, timeout=2):
                    logger.info("fusion-mlx 服务就绪")
                    return
            except Exception:
                time.sleep(1)
        logger.warning("fusion-mlx 服务就绪超时")

    def get_status(self) -> Dict[str, Any]:
        """获取完整状态信息"""
        health = self.health_check()
        return {
            "running": self.is_running,
            "pid": self.process.pid if self.process else None,
            "host": self.config.host,
            "port": self.config.port,
            "health": health,
            "model": self.config.model or "default",
            "quant": self.config.quant,
            "max_memory_gb": self.config.max_memory_gb,
        }


# ─── 硬件监控 ──────────────────────────────────────────────────────

class HardwareMonitor:
    """Apple Silicon 硬件状态监控"""

    def get_metrics(self) -> Dict[str, Any]:
        """获取当前硬件指标"""
        metrics = {
            "memory": self._get_memory_usage(),
            "cpu": self._get_cpu_usage(),
            "gpu": self._get_gpu_usage(),
            "mlx": self._get_mlx_metrics(),
        }
        return metrics

    def _get_memory_usage(self) -> Dict[str, float]:
        """获取统一内存使用情况"""
        try:
            import psutil
            mem = psutil.virtual_memory()
            return {
                "total_gb": round(mem.total / (1024**3), 1),
                "used_gb": round(mem.used / (1024**3), 1),
                "percent": mem.percent,
            }
        except ImportError:
            # 回退到 vm_stat
            try:
                result = subprocess.run(
                    ["vm_stat"],
                    capture_output=True, text=True, check=True
                )
                return {"raw": result.stdout}
            except Exception:
                return {"error": "无法获取内存信息"}

    def _get_cpu_usage(self) -> Dict[str, Any]:
        """获取 CPU 使用率"""
        try:
            import psutil
            return {
                "percent": psutil.cpu_percent(interval=0.1),
                "count": psutil.cpu_count(),
            }
        except ImportError:
            try:
                result = subprocess.run(
                    ["top", "-l", "1", "-n", "0", "-stats", "cpu"],
                    capture_output=True, text=True, check=True
                )
                return {"raw": result.stdout.split('\n')[0] if result.stdout else ""}
            except Exception:
                return {"error": "无法获取 CPU 信息"}

    def _get_gpu_usage(self) -> Dict[str, Any]:
        """获取 GPU 使用情况（通过 Metal 性能状态）"""
        try:
            result = subprocess.run(
                ["sudo", "powermetrics", "--samplers", "gpu_power", "-i", "100", "-n", "1"],
                capture_output=True, text=True, timeout=2,
            )
            return {"raw": result.stdout}
        except Exception:
            return {"error": "无法获取 GPU 信息（需要管理员权限）"}

    def _get_mlx_metrics(self) -> Dict[str, Any]:
        """获取 MLX 运行时指标"""
        try:
            result = subprocess.run(
                [sys.executable, "-c", """
import mlx.core as mx
print(mx.metal.device_info())
"""],
                capture_output=True, text=True, timeout=5,
            )
            return {"info": result.stdout.strip()}
        except Exception:
            return {"error": "无法获取 MLX 指标"}


# ─── JSON-RPC 服务器 ───────────────────────────────────────────────

class JSONRPCRequestHandler(BaseHTTPRequestHandler):
    """JSON-RPC over HTTP 请求处理器"""

    server: 'MLXDaemonServer'  # type hint

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            request = json.loads(body.decode())
            response = self.server.handle_request(request)
        except Exception as e:
            response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": str(e)},
            }

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        logger.debug(format % args)


class MLXDaemonServer:
    """MLX 守护进程主服务器"""

    def __init__(self, config: MLXConfig):
        self.config = config
        self.process_manager = MLXProcessManager(config)
        self.hardware_monitor = HardwareMonitor()
        self.http_server: Optional[HTTPServer] = None
        self._request_id = 0

    def start(self):
        """启动守护进程"""
        # 启动 HTTP JSON-RPC 服务
        addr = (self.config.host, self.config.port + 1)  # 使用 8001 作为管理端口
        self.http_server = HTTPServer(
            addr,
            lambda *args: JSONRPCRequestHandler(*args, self)
        )
        thread = threading.Thread(target=self.http_server.serve_forever, daemon=True)
        thread.start()
        logger.info(f"MLX Daemon 管理服务启动: {addr[0]}:{addr[1]}")

        # 自动启动 fusion-mlx
        if self.config.daemon:
            self.process_manager.start()

        # 保持主线程运行
        try:
            signal.pause()
        except KeyboardInterrupt:
            self.stop()

    def stop(self):
        """停止守护进程"""
        self.process_manager.stop()
        if self.http_server:
            self.http_server.shutdown()
        logger.info("MLX Daemon 已停止")

    def handle_request(self, request: dict) -> dict:
        """处理 JSON-RPC 请求"""
        method = request.get("method", "")
        params = request.get("params", {}) or {}
        req_id = request.get("id")

        try:
            result = self._dispatch(method, params)
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": result,
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32603, "message": str(e)},
            }

    def _dispatch(self, method: str, params: dict) -> Any:
        handlers = {
            "mlx.start": lambda: self.process_manager.start(),
            "mlx.stop": lambda: self.process_manager.stop(),
            "mlx.restart": lambda: self.process_manager.restart(),
            "mlx.status": lambda: self.process_manager.get_status(),
            "mlx.health": lambda: self.process_manager.health_check(),
            "mlx.set_model": lambda: self._set_model(params.get("model", "")),
            "hardware.metrics": lambda: self.hardware_monitor.get_metrics(),
            "ping": lambda: {"pong": True, "version": "0.1.0"},
        }
        handler = handlers.get(method)
        if handler is None:
            raise ValueError(f"未知方法: {method}")
        return handler()

    def _set_model(self, model: str):
        self.config.model = model
        return {"status": "ok", "model": model}


# ─── 入口 ──────────────────────────────────────────────────────────

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Fusion Studio MLX Daemon")
    parser.add_argument("--mlx-path", default=str(Path.home() / "claude-home" / "fusion-mlx"))
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=11434)
    parser.add_argument("--model", default="")
    parser.add_argument("--quant", default="4bit")
    parser.add_argument("--max-memory", type=int, default=16)
    parser.add_argument("--no-daemon", action="store_true", help="仅启动管理服务，不自动启动 MLX")

    args = parser.parse_args()

    config = MLXConfig(
        mlx_path=args.mlx_path,
        host=args.host,
        port=args.port,
        model=args.model,
        quant=args.quant,
        max_memory_gb=args.max_memory,
        daemon=not args.no_daemon,
    )

    server = MLXDaemonServer(config)
    logger.info(f"MLX Daemon 启动配置: {config}")
    server.start()


if __name__ == "__main__":
    main()