use std::path::PathBuf;
use std::sync::Arc;
use tokio::net::UnixListener;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use serde::{Deserialize, Serialize};
use env_daemon::{HealthChecker, RepairEngine, HealthCheckItem, RepairResult};

/// JSON-RPC 请求
#[derive(Debug, Deserialize)]
struct JsonRpcRequest {
    #[serde(rename = "jsonrpc")]
    jsonrpc: String,
    id: u64,
    method: String,
    params: Option<serde_json::Value>,
}

/// JSON-RPC 响应
#[derive(Debug, Serialize)]
struct JsonRpcResponse {
    #[serde(rename = "jsonrpc")]
    jsonrpc: String,
    id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<JsonRpcError>,
}

#[derive(Debug, Serialize)]
struct JsonRpcError {
    code: i32,
    message: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();

    let socket_path = "/tmp/fusion-studio.sock";

    // 清理旧的 socket 文件
    if std::path::Path::new(socket_path).exists() {
        std::fs::remove_file(socket_path)?;
    }

    let listener = UnixListener::bind(socket_path)?;
    println!("env-daemon 启动，监听: {}", socket_path);

    let health_checker = Arc::new(HealthChecker::new());
    let repair_engine = Arc::new(RepairEngine::new());

    loop {
        let (mut stream, _addr) = listener.accept().await?;
        let checker = Arc::clone(&health_checker);
        let repairer = Arc::clone(&repair_engine);

        tokio::spawn(async move {
            let mut buf = vec![0u8; 1024 * 64];
            match stream.read(&mut buf).await {
                Ok(n) if n > 0 => {
                    let request_str = String::from_utf8_lossy(&buf[..n]);
                    match serde_json::from_str::<JsonRpcRequest>(&request_str) {
                        Ok(req) => {
                            let response = handle_request(req, &checker, &repairer).await;
                            if let Ok(json) = serde_json::to_string(&response) {
                                let _ = stream.write_all(json.as_bytes()).await;
                            }
                        }
                        Err(e) => {
                            let error_resp = JsonRpcResponse {
                                jsonrpc: "2.0".into(),
                                id: 0,
                                result: None,
                                error: Some(JsonRpcError {
                                    code: -32700,
                                    message: format!("解析错误: {}", e),
                                }),
                            };
                            if let Ok(json) = serde_json::to_string(&error_resp) {
                                let _ = stream.write_all(json.as_bytes()).await;
                            }
                        }
                    }
                }
                _ => {}
            }
        });
    }
}

async fn handle_request(
    req: JsonRpcRequest,
    checker: &HealthChecker,
    repairer: &RepairEngine,
) -> JsonRpcResponse {
    let result = match req.method.as_str() {
        "env.health_check" => {
            let items = checker.run_all_checks().await;
            serde_json::to_value(items).ok()
        }
        "env.repair" => {
            let item_id = req.params
                .and_then(|p| p.get("item_id").and_then(|v| v.as_str().map(String::from)))
                .unwrap_or_default();
            let result = repairer.repair(&item_id).await;
            serde_json::to_value(result).ok()
        }
        "env.repair_all" => {
            let items = checker.run_all_checks().await;
            let mut results = Vec::new();
            for item in items {
                if item.status == env_daemon::CheckStatus::Failed && item.fixable {
                    results.push(repairer.repair(&item.id).await);
                }
            }
            serde_json::to_value(results).ok()
        }
        "ping" => {
            Some(serde_json::json!({ "pong": true, "version": "0.1.0" }))
        }
        _ => {
            return JsonRpcResponse {
                jsonrpc: "2.0".into(),
                id: req.id,
                result: None,
                error: Some(JsonRpcError {
                    code: -32601,
                    message: format!("未知方法: {}", req.method),
                }),
            };
        }
    };

    JsonRpcResponse {
        jsonrpc: "2.0".into(),
        id: req.id,
        result,
        error: None,
    }
}