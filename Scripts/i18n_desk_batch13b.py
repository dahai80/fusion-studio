import sys

PATH = "FusionStudio/Common/I18nService.swift"

# (key, zh, en, ja, ko)
TUPLES = [
    ("desk_tab_templates", "模板", "Templates", "テンプレート", "템플릿"),
    ("desk_tab_workflows", "工作流", "Workflows", "ワークフロー", "워크플로"),
    ("desk_tab_agents", "智能体", "Agents", "エージェント", "에이전트"),
    ("desk_tab_sessions", "会话", "Sessions", "セッション", "세션"),
    ("desk_tab_permissions", "权限", "Permissions", "権限", "권한"),
    ("desk_tab_mlx", "MLX", "MLX", "MLX", "MLX"),
    ("desk_tab_system", "系统", "System", "システム", "시스템"),
    ("desk_tab_events", "事件", "Events", "イベント", "이벤트"),
    ("desk_close", "关闭", "Close", "閉じる", "닫기"),
    ("desk_loading", "加载中...", "Loading...", "読み込み中...", "로딩 중..."),
    ("desk_name", "名称", "Name", "名称", "이름"),
    ("desk_category", "分类", "Category", "分類", "분류"),
    ("desk_description", "描述", "Description", "説明", "설명"),
    ("desk_create", "创建", "Create", "作成", "만들기"),
    ("desk_cancel", "取消", "Cancel", "キャンセル", "취소"),
    ("desk_save", "保存", "Save", "保存", "저장"),
    ("desk_edit", "编辑", "Edit", "編集", "편집"),
    ("desk_delete", "删除", "Delete", "削除", "삭제"),
    ("desk_status", "状态", "Status", "ステータス", "상태"),
    ("desk_refresh", "刷新", "Refresh", "更新", "새로고침"),
    ("desk_svc_notConnected", "Fusion-CoWork 服务未连接", "Fusion-CoWork service not connected", "Fusion-CoWork サービス未接続", "Fusion-CoWork 서비스 미연결"),
    ("desk_svc_notConnectedHint", "请启动 fusion-cowork 服务后重试（终端运行 ./start.sh start，或在 设置→上游服务 中启动）", "Please start the fusion-cowork service and retry (run ./start.sh start in terminal, or start in Settings → Upstream Services)", "fusion-cowork サービスを起動して再試行してください（ターミナルで ./start.sh start を実行、または 設定→アップストリームサービス で起動）", "fusion-cowork 서비스를 시작한 후 재시도하세요 (터미널에서 ./start.sh start 실행, 또는 설정→업스트림 서비스에서 시작)"),
    ("desk_reconnect", "重新连接", "Reconnect", "再接続", "다시 연결"),
    ("desk_svc_notReady", "服务未就绪", "Service not ready", "サービス未準備", "서비스 미준비"),
    ("desk_searchTemplates", "搜索模板...", "Search templates...", "テンプレートを検索...", "템플릿 검색..."),
    ("desk_tpl_count", "%d 个模板", "%d templates", "%d テンプレート", "%d 템플릿"),
    ("desk_noTemplates", "暂无模板", "No templates", "テンプレートなし", "템플릿 없음"),
    ("desk_tpl_detail", "模板详情", "Template detail", "テンプレート詳細", "템플릿 상세"),
    ("desk_steps", "步骤", "Steps", "手順", "단계"),
    ("desk_tpl_runResult", "模板 %@: %@", "Template %@: %@", "テンプレート %@: %@", "템플릿 %@: %@"),
    ("desk_tpl_runFail", "模板 %@: 执行失败", "Template %@: failed", "テンプレート %@: 実行失敗", "템플릿 %@: 실행 실패"),
    ("desk_wf_promptPlaceholder", "输入自然语言创建工作流...", "Enter natural language to create a workflow...", "自然言語でワークフローを作成...", "자연어로 워크플로 생성..."),
    ("desk_wf_count", "%d 个工作流", "%d workflows", "%d ワークフロー", "%d 워크플로"),
    ("desk_wf_execStatus", "执行状态", "Execution status", "実行状態", "실행 상태"),
    ("desk_noWorkflows", "暂无工作流，输入提示语创建", "No workflows, enter a prompt to create", "ワークフローなし、プロンプトを入力して作成", "워크플로 없음, 프롬프트 입력하여 생성"),
    ("desk_wf_execStatusTitle", "工作流执行状态", "Workflow execution status", "ワークフロー実行状態", "워크플로 실행 상태"),
    ("desk_wf_noRunning", "当前无执行中的工作流", "No running workflows", "実行中のワークフローなし", "실행 중인 워크플로 없음"),
    ("desk_wf_currentNode", "当前节点: %@", "Current node: %@", "現在のノード: %@", "현재 노드: %@"),
    ("desk_agent_taskPlaceholder", "提交任务给智能体...", "Submit task to agent...", "エージェントにタスクを送信...", "에이전트에 작업 제출..."),
    ("desk_submit", "提交", "Submit", "送信", "제출"),
    ("desk_agent_count", "%d 个智能体", "%d agents", "%d エージェント", "%d 에이전트"),
    ("desk_noAgents", "暂无智能体", "No agents", "エージェントなし", "에이전트 없음"),
    ("desk_agent_id", "ID: %@", "ID: %@", "ID: %@", "ID: %@"),
    ("desk_agent_taskSubmitted", "任务 %@ 已提交", "Task %@ submitted", "タスク %@ 送信済み", "작업 %@ 제출됨"),
    ("desk_agent_viewStatus", "查看状态", "View status", "ステータスを表示", "상태 보기"),
    ("desk_agent_status", "状态: %@", "Status: %@", "ステータス: %@", "상태: %@"),
    ("desk_agent_progress", "进度: %@", "Progress: %@", "進捗: %@", "진행률: %@"),
    ("desk_session_new", "新建会话", "New session", "新規セッション", "새 세션"),
    ("desk_session_count", "%d 个会话", "%d sessions", "%d セッション", "%d 세션"),
    ("desk_noSessions", "暂无会话", "No sessions", "セッションなし", "세션 없음"),
    ("desk_session_steps", "步骤: %d", "Steps: %d", "手順: %d", "단계: %d"),
    ("desk_session_fork", "分叉", "Fork", "分岐", "분기"),
    ("desk_session_edit", "编辑会话", "Edit session", "セッションを編集", "세션 편집"),
    ("desk_session_namePlaceholder", "会话名称", "Session name", "セッション名", "세션 이름"),
    ("desk_session_detail", "会话详情", "Session detail", "セッション詳細", "세션 상세"),
    ("desk_session_stepCount", "步骤数", "Step count", "手順数", "단계 수"),
    ("desk_perm_rules", "权限规则", "Permission rules", "権限ルール", "권한 규칙"),
    ("desk_perm_checkTool", "检查工具", "Check tool", "ツールを確認", "도구 확인"),
    ("desk_perm_check", "检查", "Check", "確認", "확인"),
    ("desk_perm_resetAll", "重置全部", "Reset all", "すべてリセット", "모두 재설정"),
    ("desk_perm_checkResult", "工具 %@: %@", "Tool %@: %@", "ツール %@: %@", "도구 %@: %@"),
    ("desk_perm_allowed", "允许", "Allowed", "許可", "허용"),
    ("desk_perm_denied", "拒绝", "Denied", "拒否", "거부"),
    ("desk_perm_noRules", "暂无权限规则", "No permission rules", "権限ルールなし", "권한 규칙 없음"),
    ("desk_perm_scope", "范围: %@", "Scope: %@", "範囲: %@", "범위: %@"),
    ("desk_perm_toggle", "切换", "Toggle", "切り替え", "전환"),
    ("desk_mlx_status", "Fusion-MLX 状态", "Fusion-MLX status", "Fusion-MLX ステータス", "Fusion-MLX 상태"),
    ("desk_mlx_running", "运行中", "Running", "実行中", "실행 중"),
    ("desk_mlx_stopped", "已停止", "Stopped", "停止", "중지됨"),
    ("desk_mlx_noModels", "无可用模型", "No models available", "モデルなし", "사용 가능한 모델 없음"),
    ("desk_mlx_modelList", "模型列表", "Model list", "モデルリスト", "모델 목록"),
    ("desk_mlx_modelCount", "%d 个模型", "%d models", "%d モ델", "%d 모델"),
    ("desk_mlx_runningTitle", "Fusion-MLX 运行中", "Fusion-MLX running", "Fusion-MLX 実行中", "Fusion-MLX 실행 중"),
    ("desk_mlx_stoppedTitle", "Fusion-MLX 未启动", "Fusion-MLX not started", "Fusion-MLX 未起動", "Fusion-MLX 미시작"),
    ("desk_mlx_manageHint", "请通过 UpstreamServiceManager 管理 MLX 生命周期", "Manage MLX lifecycle via UpstreamServiceManager", "UpstreamServiceManager で MLX ライフサイクルを管理", "UpstreamServiceManager로 MLX 라이프사이클 관리"),
    ("desk_sys_info", "系统信息", "System info", "システム情報", "시스템 정보"),
    ("desk_sys_platform", "平台", "Platform", "プラットフォーム", "플랫폼"),
    ("desk_sys_cpuCores", "CPU 核心数", "CPU cores", "CPU コア数", "CPU 코어 수"),
    ("desk_sys_memoryTotal", "内存总量", "Memory total", "メモリ合計", "메모리 총량"),
    ("desk_sys_memoryUsed", "内存使用", "Memory used", "メモリ使用量", "메모리 사용량"),
    ("desk_sys_diskFree", "磁盘剩余", "Disk free", "ディスク空き", "디스크 여유"),
    ("desk_sys_nodeCategories", "节点分类", "Node categories", "ノード分類", "노드 분류"),
    ("desk_sys_nodeList", "节点列表", "Node list", "ノードリスト", "노드 목록"),
    ("desk_sys_loading", "系统信息加载中...", "Loading system info...", "システム情報読み込み中...", "시스템 정보 로딩 중..."),
    ("desk_sys_nodeDetail", "节点详情", "Node detail", "ノード詳細", "노드 상세"),
    ("desk_sys_inputs", "输入参数", "Input parameters", "入力パラメータ", "입력 매개변수"),
    ("desk_sys_outputs", "输出", "Output", "出力", "출력"),
    ("desk_evt_stream", "事件流", "Event stream", "イベントストリーム", "이벤트 스트림"),
    ("desk_evt_polling", "轮询中", "Polling", "ポーリング中", "폴링 중"),
    ("desk_evt_subscribed", "已订阅", "Subscribed", "購読済み", "구독됨"),
    ("desk_evt_count", "%d 个事件", "%d events", "%d イベント", "%d 이벤트"),
    ("desk_evt_stopPoll", "停止轮询", "Stop polling", "ポーリング停止", "폴링 중지"),
    ("desk_evt_startPoll", "开始轮询", "Start polling", "ポーリング開始", "폴링 시작"),
    ("desk_noEvents", "暂无事件", "No events", "イベントなし", "이벤트 없음"),
    ("desk_evt_source", "来源: %@", "Source: %@", "送信元: %@", "출처: %@"),
]

with open(PATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

enum_anchor = '    case art_cv_toc = "art_cv_toc"\n'
dict_anchors = {
    "zh": '    "art_cv_toc": "章节目录",\n',
    "en": '    "art_cv_toc": "Table of Contents",\n',
    "ja": '    "art_cv_toc": "目次",\n',
    "ko": '    "art_cv_toc": "목차",\n',
}
lang_idx = {"zh": 1, "en": 2, "ja": 3, "ko": 4}

def esc(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"")

enum_block = [enum_anchor]
for t in TUPLES:
    enum_block.append('    case %s = "%s"\n' % (t[0], t[0]))
enum_block_str = "".join(enum_block)

dict_inserts = {}
for lang in ("zh", "en", "ja", "ko"):
    blk = [dict_anchors[lang]]
    li = lang_idx[lang]
    for t in TUPLES:
        blk.append('    "%s": "%s",\n' % (t[0], esc(t[li])))
    dict_inserts[lang] = "".join(blk)

out = []
for line in lines:
    if line == enum_anchor:
        out.append(enum_block_str)
    elif line == dict_anchors["zh"]:
        out.append(dict_inserts["zh"])
    elif line == dict_anchors["en"]:
        out.append(dict_inserts["en"])
    elif line == dict_anchors["ja"]:
        out.append(dict_inserts["ja"])
    elif line == dict_anchors["ko"]:
        out.append(dict_inserts["ko"])
    else:
        out.append(line)

with open(PATH, "w", encoding="utf-8") as f:
    f.writelines(out)

print("inserted %d keys" % len(TUPLES))
