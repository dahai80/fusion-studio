use std::path::PathBuf;
use std::sync::Arc;
use std::os::unix::fs::PermissionsExt;
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

/// 最大重试次数
const MAX_RETRIES: u32 = 5;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();

    let socket_path = "/tmp/fusion-studio.sock";
    let health_checker = Arc::new(HealthChecker::new());
    let repair_engine = Arc::new(RepairEngine::new());

    let mut retry_count = 0;

    loop {
        match run_server(socket_path, &health_checker, &repair_engine).await {
            Ok(()) => {
                // 正常退出，重置重试计数
                retry_count = 0;
                println!("env-daemon 正常退出，重新启动...");
            }
            Err(e) => {
                retry_count += 1;
                eprintln!("env-daemon 异常退出 (第{}次): {}", retry_count, e);

                if retry_count >= MAX_RETRIES {
                    eprintln!("超过最大重试次数 ({}), 退出", MAX_RETRIES);
                    return Err(e);
                }

                let delay = std::time::Duration::from_secs(1u64 << retry_count.min(5));
                println!("{} 秒后重启...", delay.as_secs());
                tokio::time::sleep(delay).await;
            }
        }
    }
}

async fn run_server(
    socket_path: &str,
    health_checker: &Arc<HealthChecker>,
    repair_engine: &Arc<RepairEngine>,
) -> anyhow::Result<()> {
    // 清理旧的 socket 文件
    if std::path::Path::new(socket_path).exists() {
        std::fs::remove_file(socket_path)?;
    }

    let listener = UnixListener::bind(socket_path)?;

    // 设置 socket 权限为 0600（仅所有者可读写）
    let metadata = std::fs::metadata(socket_path)?;
    let mut perms = metadata.permissions();
    perms.set_mode(0o600);
    std::fs::set_permissions(socket_path, perms)?;

    println!("env-daemon 启动，监听: {} (权限: 0600)", socket_path);

    loop {
        // 设置 accept 超时（方便外部检测僵死）
        let accept_fut = listener.accept();
        let timeout_fut = tokio::time::sleep(std::time::Duration::from_secs(30));

        let (stream, _addr) = tokio::select! {
            result = accept_fut => result?,
            _ = timeout_fut => {
                // 30 秒无连接，打印心跳并继续
                tracing::debug!("env-daemon 心跳: 运行中");
                continue;
            }
        };

        let checker = Arc::clone(health_checker);
        let repairer = Arc::clone(repair_engine);

        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream, checker, repairer).await {
                eprintln!("处理连接失败: {}", e);
            }
        });
    }
}

async fn handle_connection(
    mut stream: tokio::net::UnixStream,
    checker: Arc<HealthChecker>,
    repairer: Arc<RepairEngine>,
) -> anyhow::Result<()> {
    let mut buf = vec![0u8; 1024 * 64];

    loop {
        match stream.read(&mut buf).await {
            Ok(0) => break, // 连接关闭
            Ok(n) => {
                let request_str = String::from_utf8_lossy(&buf[..n]);
                match serde_json::from_str::<JsonRpcRequest>(&request_str) {
                    Ok(req) => {
                        let response = handle_request(req, &checker, &repairer).await;
                        if let Ok(json) = serde_json::to_string(&response) {
                            let mut resp_data = json.into_bytes();
                            resp_data.push(0x0A); // 换行符分隔
                            if stream.write_all(&resp_data).await.is_err() {
                                break;
                            }
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
                            let mut resp_data = json.into_bytes();
                            resp_data.push(0x0A);
                            let _ = stream.write_all(&resp_data).await;
                        }
                        break;
                    }
                }
            }
            Err(e) => {
                eprintln!("读取错误: {}", e);
                break;
            }
        }
    }
    Ok(())
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