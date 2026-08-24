use env_daemon::{HealthCheckItem, HealthChecker, RepairEngine, RepairResult};
use serde::{Deserialize, Serialize};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::io::AsRawFd;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;

// ─── peer credential (macOS LOCAL_PEERCRED) ────────────────────────
// 拒绝非同 UID 连接, 防止本地其他用户/低权限进程伪造 JSON-RPC 调用后端控制面
use libc::{c_void, getsockopt, socklen_t, xucred, SOL_LOCAL, LOCAL_PEERCRED};

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

    // socket 移出 /tmp: 放用户私有目录 ~/.fusion-studio/run/, 0700 目录权限
    // /tmp 系统级可写, 其他 UID 可抢占同名 socket 做劫持; 私有目录杜绝该攻击面
    // env.* 方法由 agent-studio 中央路由转发, Swift 不直连本 socket
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let default_sock = format!("{}/.fusion-studio/run/fusion-env-daemon.sock", home);
    let socket_path =
        std::env::var("FUSION_ENV_DAEMON_SOCKET").unwrap_or_else(|_| default_sock.clone());
    let health_checker = Arc::new(HealthChecker::new());
    let repair_engine = Arc::new(RepairEngine::new());

    // 启动 uid: peer credential 校验基准, 仅允许同 uid 连接
    let our_uid = unsafe { libc::getuid() };

    let mut retry_count = 0;

    loop {
        match run_server(&socket_path, &health_checker, &repair_engine, our_uid).await {
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

/// 取连接对端 uid (macOS LOCAL_PEERCRED), 失败返回 None
fn peer_uid(fd: std::os::unix::io::RawFd) -> Option<u32> {
    let mut cred: xucred = unsafe { std::mem::zeroed() };
    let mut len: socklen_t = std::mem::size_of::<xucred>() as socklen_t;
    let rc = unsafe {
        getsockopt(
            fd,
            SOL_LOCAL,
            LOCAL_PEERCRED,
            &mut cred as *mut xucred as *mut c_void,
            &mut len,
        )
    };
    if rc == 0 && cred.cr_uid != u32::MAX {
        Some(cred.cr_uid)
    } else {
        None
    }
}

async fn run_server(
    socket_path: &str,
    health_checker: &Arc<HealthChecker>,
    repair_engine: &Arc<RepairEngine>,
    our_uid: u32,
) -> anyhow::Result<()> {
    // 确保 socket 父目录存在并设 0700 (仅所有者可进入, 阻止其他用户 bind 同名/读取)
    let sock_dir = std::path::Path::new(socket_path)
        .parent()
        .unwrap_or(std::path::Path::new("/tmp"));
    std::fs::create_dir_all(sock_dir)?;
    let dir_meta = std::fs::metadata(sock_dir)?;
    let mut dir_perms = dir_meta.permissions();
    dir_perms.set_mode(0o700);
    std::fs::set_permissions(sock_dir, dir_perms)?;

    // 清理旧的 socket 文件
    if std::path::Path::new(socket_path).exists() {
        std::fs::remove_file(socket_path)?;
    }

    let listener = UnixListener::bind(socket_path)?;

    // 设置 socket 文件权限为 0600（仅所有者可读写）
    let metadata = std::fs::metadata(socket_path)?;
    let mut perms = metadata.permissions();
    perms.set_mode(0o600);
    std::fs::set_permissions(socket_path, perms)?;

    println!(
        "env-daemon 启动，监听: {} (目录 0700, socket 0600, 仅同 UID {} 可连)",
        socket_path, our_uid
    );

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

        // peer credential UID 校验: 拒绝非同 uid 连接
        let peer = peer_uid(stream.as_raw_fd());
        match peer {
            Some(uid) if uid == our_uid => {}
            other => {
                tracing::warn!("拒绝连接: peer uid {:?} != 本进程 uid {}", other, our_uid);
                // 立即关闭, 不进入 handle_connection
                continue;
            }
        }

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
            let item_id = req
                .params
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
        "ping" => Some(serde_json::json!({ "pong": true, "version": "0.1.0" })),
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
