# M7 GUI 实现计划 — fusion-studio 集群可视化面板

Importers/callers: ModuleDetailView路由到新视图; FusionSidebarView展示子模块; IPCClient新增multiNode方法
Affected API: AppState.Module新增枚举值; IPCClient新增16个RPC方法
Data schemas: ClusterStats/NodeInfo/TaskInfo等Codable结构体
用户指令: "现在启动defer的GUI部分，fusion-studio工程在~/fusion/fusion-studio目录"

## 背景

PRD M7-01~05 定义了5个GUI面板，M7-06(监控API)已在fusion-multi-node中实现。

## 实现顺序和文件清单

```
FusionStudio/Modules/MultiNode/
├── MultiNodeModels.swift        # 数据模型
├── MultiNodeEngine.swift        # 数据引擎 (ObservableObject)
├── ClusterOverviewView.swift    # M7-01 集群总览
├── ClusterTopologyView.swift    # M7-02 拓扑图
├── TaskMonitorView.swift        # M7-03 任务监控
├── NodeActionsView.swift        # M7-04 节点操作 + AutoscalerConfigView
└── AlertManager.swift           # M7-05 告警通知
```

修改: IPCClient.swift, AppState.swift, ModuleDetailView.swift, FusionSidebarView.swift
