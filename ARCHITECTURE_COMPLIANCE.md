# 架构合规整改计划

审计日期: 2026-08-02
关联 Issue: #61
违规等级: P0
合规评级: D

层级定位: 重新定位为独立层级 - macOS GUI桌面应用入口 (当前错误归入四通用工具生态)
核心职责: 作为Fusion全系产品的macOS原生GUI统一入口

违规项与整改:

1. 层级归属错误 - 177个Swift文件/88742行SwiftUI应用, 不是通用创作中台, 是macOS GUI入口 - 重新定位为独立层级 - P0-S1
2. 硬编码L5模块 - EduK12/FSB/Simulation直接内嵌垂直场景GUI, 违反L4不面向垂直场景原则 - 改为动态插件加载 - P0-S1
3. 内嵌底层守护进程 - mlx-daemon/env-daemon属L2/L3系统服务 - 独立为系统服务项目 - P0-S2
4. 巨型单文件 - AgentStudioView.swift 5397行/IPCClient.swift 3153行 - 拆分 - P0-S2
5. 模块重叠 - AIAgent vs Agent/KB vs KnowledgeBase/CoWork vs TeamCollab - 消除重叠 - P0-S3
6. 空壳目录 - supervisor/file-daemon为空 - 清理 - P0-S3

整改阶段:
P0-S1: 重新定位层级, L5模块改为动态插件
P0-S2: 守护进程独立, 拆分巨型文件
P0-S3: 消除模块重叠, 清理空壳目录

合规标准: fusion-studio应作为纯GUI入口, 通过动态插件机制加载各产品界面, 不硬编码垂直场景, 不内嵌系统服务
