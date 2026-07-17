use std::collections::HashMap;
use std::process::Command;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};
use anyhow::{Result, Context};

/// 环境健康检查项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthCheckItem {
    pub id: String,
    pub label: String,
    pub status: CheckStatus,
    pub detail: Option<String>,
    pub fixable: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CheckStatus {
    #[serde(rename = "passed")]
    Passed,
    #[serde(rename = "failed")]
    Failed,
    #[serde(rename = "checking")]
    Checking,
}

/// 修复结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepairResult {
    pub item_id: String,
    pub success: bool,
    pub message: String,
    pub logs: Vec<String>,
}

/// 环境健康检查引擎
pub struct HealthChecker {
    home_dir: PathBuf,
    fusion_dir: PathBuf,
    claude_home: PathBuf,
}

impl HealthChecker {
    pub fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/Users/dahai".to_string());
        let home_dir = PathBuf::from(&home);
        Self {
            home_dir: home_dir.clone(),
            fusion_dir: home_dir.join("fusion"),
            claude_home: home_dir.join("claude-home"),
        }
    }

    /// 运行全部检查
    pub async fn run_all_checks(&self) -> Vec<HealthCheckItem> {
        let mut results = Vec::new();
        results.push(self.check_xcode_cli());
        results.push(self.check_homebrew());
        results.push(self.check_python());
        results.push(self.check_mlx());
        results.push(self.check_pybullet());
        results.push(self.check_rust());
        results.push(self.check_fusion_mlx_service());
        results
    }

    /// 检查 Xcode CLI Tools
    fn check_xcode_cli(&self) -> HealthCheckItem {
        let output = Command::new("xcode-select")
            .args(["-p"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let path = String::from_utf8_lossy(&o.stdout).trim().to_string();
                HealthCheckItem {
                    id: "xcode".into(),
                    label: "Xcode CLI Tools".into(),
                    status: CheckStatus::Passed,
                    detail: Some(path),
                    fixable: true,
                }
            }
            _ => HealthCheckItem {
                id: "xcode".into(),
                label: "Xcode CLI Tools".into(),
                status: CheckStatus::Failed,
                detail: Some("未安装".into()),
                fixable: true,
            },
        }
    }

    /// 检查 Homebrew
    fn check_homebrew(&self) -> HealthCheckItem {
        let output = Command::new("brew")
            .args(["--version"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let ver = String::from_utf8_lossy(&o.stdout)
                    .lines().next().unwrap_or("").to_string();
                HealthCheckItem {
                    id: "homebrew".into(),
                    label: "Homebrew".into(),
                    status: CheckStatus::Passed,
                    detail: Some(ver),
                    fixable: true,
                }
            }
            _ => HealthCheckItem {
                id: "homebrew".into(),
                label: "Homebrew".into(),
                status: CheckStatus::Failed,
                detail: Some("未安装".into()),
                fixable: true,
            },
        }
    }

    /// 检查 Python 环境
    fn check_python(&self) -> HealthCheckItem {
        let output = Command::new("python3")
            .args(["--version"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let ver = String::from_utf8_lossy(&o.stdout).trim().to_string();
                let has_pip = Command::new("pip3")
                    .args(["--version"])
                    .output().is_ok();
                HealthCheckItem {
                    id: "python".into(),
                    label: "Python 3.11+".into(),
                    status: if has_pip { CheckStatus::Passed } else { CheckStatus::Failed },
                    detail: Some(ver),
                    fixable: true,
                }
            }
            _ => HealthCheckItem {
                id: "python".into(),
                label: "Python 3.11+".into(),
                status: CheckStatus::Failed,
                detail: Some("python3 未找到".into()),
                fixable: true,
            },
        }
    }

    /// 检查 MLX 环境
    fn check_mlx(&self) -> HealthCheckItem {
        let output = Command::new("python3")
            .args(["-c", "import mlx; print(mlx.__version__)"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let ver = String::from_utf8_lossy(&o.stdout).trim().to_string();
                HealthCheckItem {
                    id: "mlx".into(),
                    label: "MLX 环境".into(),
                    status: CheckStatus::Passed,
                    detail: Some(format!("mlx {}", ver)),
                    fixable: true,
                }
            }
            _ => HealthCheckItem {
                id: "mlx".into(),
                label: "MLX 环境".into(),
                status: CheckStatus::Failed,
                detail: Some("mlx 未安装".into()),
                fixable: true,
            },
        }
    }

    /// 检查 PyBullet
    fn check_pybullet(&self) -> HealthCheckItem {
        let output = Command::new("python3")
            .args(["-c", "import pybullet; print(pybullet.__version__)"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let ver = String::from_utf8_lossy(&o.stdout).trim().to_string();
                HealthCheckItem {
                    id: "pybullet".into(),
                    label: "PyBullet".into(),
                    status: CheckStatus::Passed,
                    detail: Some(format!("pybullet {}", ver)),
                    fixable: true,
                }
            }
            _ => {
                // 检查是否编译失败
                let has_source = self.fusion_dir.join("fusion-simulation").exists();
                let detail = if has_source {
                    "PyBullet 未安装或编译失败".into()
                } else {
                    "PyBullet 未安装".into()
                };
                HealthCheckItem {
                    id: "pybullet".into(),
                    label: "PyBullet".into(),
                    status: CheckStatus::Failed,
                    detail: Some(detail),
                    fixable: true,
                }
            }
        }
    }

    /// 检查 Rust 工具链
    fn check_rust(&self) -> HealthCheckItem {
        let output = Command::new("rustc")
            .args(["--version"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let ver = String::from_utf8_lossy(&o.stdout).trim().to_string();
                let has_cargo = Command::new("cargo")
                    .args(["--version"])
                    .output().is_ok();
                HealthCheckItem {
                    id: "rust".into(),
                    label: "Rust 工具链".into(),
                    status: if has_cargo { CheckStatus::Passed } else { CheckStatus::Failed },
                    detail: Some(ver),
                    fixable: true,
                }
            }
            _ => HealthCheckItem {
                id: "rust".into(),
                label: "Rust 工具链".into(),
                status: CheckStatus::Failed,
                detail: Some("rustc 未安装".into()),
                fixable: true,
            },
        }
    }

    /// 检查 fusion-mlx 服务
    fn check_fusion_mlx_service(&self) -> HealthCheckItem {
        // 检测 fusion-mlx HTTP 服务是否在运行
        let output = Command::new("curl")
            .args(["-s", "-o", "/dev/null", "-w", "%{http_code}", "http://localhost:8000/v1/models"])
            .output();
        match output {
            Ok(o) if o.status.success() => {
                let code = String::from_utf8_lossy(&o.stdout).trim().to_string();
                if code == "200" {
                    HealthCheckItem {
                        id: "fusion-mlx".into(),
                        label: "fusion-mlx 服务".into(),
                        status: CheckStatus::Passed,
                        detail: Some("运行中 (localhost:8000)".into()),
                        fixable: true,
                    }
                } else {
                    HealthCheckItem {
                        id: "fusion-mlx".into(),
                        label: "fusion-mlx 服务".into(),
                        status: CheckStatus::Failed,
                        detail: Some(format!("服务响应异常 (HTTP {})", code)),
                        fixable: true,
                    }
                }
            }
            _ => HealthCheckItem {
                id: "fusion-mlx".into(),
                label: "fusion-mlx 服务".into(),
                status: CheckStatus::Failed,
                detail: Some("未运行".into()),
                fixable: true,
            },
        }
    }
}

/// 一键修复引擎
pub struct RepairEngine {
    home_dir: PathBuf,
}

impl RepairEngine {
    pub fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/Users/dahai".to_string());
        Self {
            home_dir: PathBuf::from(&home),
        }
    }

    /// 修复指定检查项
    pub async fn repair(&self, item_id: &str) -> RepairResult {
        match item_id {
            "xcode" => self.repair_xcode_cli().await,
            "homebrew" => self.repair_homebrew().await,
            "python" => self.repair_python().await,
            "mlx" => self.repair_mlx().await,
            "pybullet" => self.repair_pybullet().await,
            "rust" => self.repair_rust().await,
            "fusion-mlx" => self.repair_fusion_mlx().await,
            _ => RepairResult {
                item_id: item_id.into(),
                success: false,
                message: format!("未知修复项: {}", item_id),
                logs: vec![],
            },
        }
    }

    async fn run_command(cmd: &str, args: &[&str]) -> (bool, Vec<String>) {
        let mut logs = Vec::new();
        logs.push(format!("$ {} {}", cmd, args.join(" ")));

        let output = Command::new(cmd)
            .args(args)
            .output();

        match output {
            Ok(o) => {
                if !o.stdout.is_empty() {
                    logs.push(String::from_utf8_lossy(&o.stdout).trim().to_string());
                }
                if !o.stderr.is_empty() {
                    logs.push(String::from_utf8_lossy(&o.stderr).trim().to_string());
                }
                (o.status.success(), logs)
            }
            Err(e) => {
                logs.push(format!("错误: {}", e));
                (false, logs)
            }
        }
    }

    async fn repair_xcode_cli(&self) -> RepairResult {
        let (success, logs) = Self::run_command("xcode-select", &["--install"]).await;
        RepairResult {
            item_id: "xcode".into(),
            success,
            message: if success { "Xcode CLI Tools 安装成功".into() } else { "安装失败，请手动安装".into() },
            logs,
        }
    }

    async fn repair_homebrew(&self) -> RepairResult {
        let script = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"";
        let (success, logs) = Self::run_command("/bin/bash", &["-c", script]).await;
        RepairResult {
            item_id: "homebrew".into(),
            success,
            message: if success { "Homebrew 安装成功".into() } else { "安装失败".into() },
            logs,
        }
    }

    async fn repair_python(&self) -> RepairResult {
        let (success, logs) = Self::run_command("brew", &["install", "python@3.11"]).await;
        RepairResult {
            item_id: "python".into(),
            success,
            message: if success { "Python 3.11 安装成功".into() } else { "安装失败".into() },
            logs,
        }
    }

    async fn repair_mlx(&self) -> RepairResult {
        let (success, logs) = Self::run_command("pip3", &["install", "mlx"]).await;
        RepairResult {
            item_id: "mlx".into(),
            success,
            message: if success { "MLX 安装成功".into() } else { "安装失败".into() },
            logs,
        }
    }

    async fn repair_pybullet(&self) -> RepairResult {
        let mut logs = Vec::new();
        logs.push("开始修复 PyBullet...".into());

        // 先尝试 pip 安装
        let (pip_ok, pip_logs) = Self::run_command("pip3", &["install", "pybullet"]).await;
        logs.extend(pip_logs);

        if pip_ok {
            return RepairResult {
                item_id: "pybullet".into(),
                success: true,
                message: "PyBullet 安装成功".into(),
                logs,
            };
        }

        // 如果 pip 失败，尝试源码编译（常见于 PyBullet 的编译问题）
        logs.push("pip 安装失败，尝试源码编译...".into());
        let (build_ok, build_logs) = Self::run_command("pip3", &[
            "install",
            "--no-binary", "pybullet",
            "pybullet",
        ]).await;
        logs.extend(build_logs);

        RepairResult {
            item_id: "pybullet".into(),
            success: build_ok,
            message: if build_ok {
                "PyBullet 源码编译安装成功".into()
            } else {
                "PyBullet 安装失败，请参考文档手动编译".into()
            },
            logs,
        }
    }

    async fn repair_rust(&self) -> RepairResult {
        let (success, logs) = Self::run_command("curl", &[
            "--proto", "=https",
            "--tlsv1.2",
            "-sSf",
            "https://sh.rustup.rs",
            "|", "sh", "-s", "--", "-y",
        ]).await;
        RepairResult {
            item_id: "rust".into(),
            success,
            message: if success { "Rust 工具链安装成功".into() } else { "安装失败".into() },
            logs,
        }
    }

    async fn repair_fusion_mlx(&self) -> RepairResult {
        // 启动 fusion-mlx 服务
        let mlx_path = self.home_dir.join("claude-home").join("fusion-mlx");
        let mut logs = Vec::new();
        logs.push(format!("尝试启动 fusion-mlx (路径: {})", mlx_path.display()));

        if mlx_path.exists() {
            let (success, cmd_logs) = Self::run_command("python3", &[
                "-m", "fusion_mlx.serve",
                "--port", "8000",
                "--daemon",
            ]).await;
            logs.extend(cmd_logs);
            RepairResult {
                item_id: "fusion-mlx".into(),
                success,
                message: if success { "fusion-mlx 服务已启动".into() } else { "启动失败".into() },
                logs,
            }
        } else {
            RepairResult {
                item_id: "fusion-mlx".into(),
                success: false,
                message: "fusion-mlx 未找到，请先安装".into(),
                logs,
            }
        }
    }
}