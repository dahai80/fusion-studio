// F-I11: ja-JP locale prompt set — translated. Natural language translated,
// technical directives verbatim (antArtifact tag, CSS :root block, hex, JSON format, Tailwind/CDN/dark/HTML/React).

import Foundation

extension DesignPrompts {

    static let jaJP = DesignPromptSet(
        systemPrompt: """
        あなたは Fusion Studio のプロの UI デザイナー兼フロントエンドエンジニアです。ユーザーの要件に基づき、高品質な HTML コンポーネントコードを生成してください。

        ## 出力仕様

        1. Tailwind CSS (CDN) でスタイリングを行い、インライン style は使用しない
        2. コンポーネントは自己完結した完全な HTML ドキュメントであり、ブラウザで直接実行できること
        3. dark テーマをサポート（デフォルトの濃い背景 #1a1a2e、テキスト #e0e0e0）
        4. レスポンシブレイアウト、Tailwind の responsive プレフィックスを使用
        5. インタラクションロジックはインライン <script> で実装
        6. フレームワークは使用しない（React/Vue/Angular）、純 HTML + Tailwind + vanilla JS
        7. CSS 変数でデザイン Token を定義:

        :root {
          --color-primary: #007AFF;
          --color-secondary: #5856D6;
          --color-success: #34C759;
          --color-warning: #FF9500;
          --color-error: #FF3B30;
          --color-bg: #1a1a2e;
          --color-surface: #16213e;
          --color-text: #e0e0e0;
          --color-text-secondary: #a0a0a0;
          --radius-sm: 6px;
          --radius-md: 10px;
          --radius-lg: 16px;
          --spacing-xs: 4px;
          --spacing-sm: 8px;
          --spacing-md: 16px;
          --spacing-lg: 24px;
        }

        ## 出力形式

        生成したコードを antArtifact タグで囲んでください:

        <antArtifact type="html" title="コンポーネント名">
        完全な HTML コード...
        </antArtifact>

        ユーザーが既存デザインの修正を要求した場合、修正後の完全なコードのみを出力してください（引き続き antArtifact で囲む）。diff は出力しない。
        コード以外に余分な説明を加えないでください。コードが最終成果物です。
        """,
        templatePrompts: [
            "login": "モダンなログインページを設計してください。濃色テーマ、メールとパスワードでのログインをサポート、「ログイン状態を保持」オプションと「パスワードをお忘れですか？」リンク、下部にソーシャルログインボタン",
            "dashboard": "データダッシュボードページを設計してください。濃色テーマ、上部ナビゲーションバー、左サイドバーメニュー、メインエリアに4つのデータカード + 折れ線グラフエリア + データテーブル",
            "landing": "製品ランディングページを設計してください。濃色テーマ、ナビゲーションバー、Hero エリア（大見出し + サブ見出し + CTA ボタン）、機能紹介エリア（3列）、料金エリア（3つの料金カード）、フッターを含む",
            "settings": "設定ページを設計してください。濃色テーマ、左タブナビゲーション（一般/セキュリティ/通知/外観）、右側に対応する設定内容、フォームコントロール（スイッチ/セレクター/入力欄）を使用",
            "chat": "チャットインターフェースを設計してください。濃色テーマ、左側に会話リスト、右側にチャットエリア（メッセージバブル + 入力欄）、送信ボタンと添付ボタンをサポート",
            "profile": "プロフィールページを設計してください。濃色テーマ、上部にアバター + 名前 + 自己紹介、下にタブ切り替え（アクティビティ/お気に入り/概要）、カードリストを表示",
            "card": "カードコンポーネント一式を設計してください：標準カード、特集カード（画像付き）、アウトラインカード、各3サイズ、Fusion Design Token を使用",
            "form": "登録フォームを設計してください。濃色テーマ、ユーザー名、メール、パスワード（強度インジケーター付き）、パスワード確認、利用規約同意チェックボックス、送信ボタンを含み、フォームバリデーションロジックあり",
            "table": "インタラクティブなデータテーブルページを設計してください。濃色テーマ、ソート、検索フィルター、ページネーションをサポート、各行にアクションボタン（編集/削除）、ヘッダークリックでソート可能",
            "nav": "ナビゲーションコンポーネント一式を設計してください：上部ナビゲーションバー（検索 + ユーザーアバター付き）、サイドバーナビゲーション（折りたたみ可能 + アイコン + ラベル）、パンくずナビゲーション、濃色テーマ",
            "modal": "モーダルコンポーネント一式を設計してください：確認ダイアログ、フォームモーダル、フルスクリーンモーダル、ボトムドロワー、オーバーレイとアニメーション付き、濃色テーマ",
            "buttons": "ボタンコンポーネント一式を設計してください：プライマリ/セカンダリ/アウトライン/テキスト/デンジャーボタン、それぞれデフォルト/hover/active/disabled 状態を含む、濃色テーマ",
        ],
        pageFlowDefaultNames: ["ホーム", "一覧", "詳細"],
        multiVariantsDefaultStyles: ["シンプル", "モダン", "ミニマル"],
        fallbackTextToUI: "モダンな濃色テーマのページを設計してください",
        fallbackImageToUIHint: "画像を参考にして UI レイアウトを生成してください",
        fallbackMultiVariants: "データカードコンポーネントを設計してください",
        fallbackLocalEditInstruction: "選択した要素を修正してください",
        fallbackPartialEditInstruction: "選択したノードの視覚スタイルを最適化してください",
        fallbackSimPanel: "スタイルバリエーションを生成してください",
        fallbackSpecDoc: "完全な設計仕様書を出力してください",
        fallbackPageFlow: "ホーム → 一覧 → 詳細 のナビゲーションフロー",
        applyLocalEditContext: { nodesJSON, instruction in
            "選択したノードの現在の状態:\n\(nodesJSON)\n\n上記ノードを修正し、以下を満たしてください: \(instruction)\n\n修正後ノードの JSON 配列のみを出力してください。他の内容は出力しないでください。形式: [{\"id\":\"...\", ...変更したプロパティ}]"
        },
        skillImageToUIPrompt: { imagePath, hint, pageName in
            "参考画像パス: \(imagePath)\n補足説明: \(hint)\nページ「\(pageName)」に対応する UI レイアウトを生成してください"
        },
        skillPartialEditPrompt: { nodesJSON, instruction in
            "以下のノードに部分修正を行ってください:\n\(nodesJSON)\n\n修正要件: \(instruction)\n\n修正後ノードの完全な JSON のみを出力してください。id は変更しないでください。形式: [{\"id\":\"...\", ...すべてのプロパティ}]"
        },
        skillSimPanelPrompt: { prompt in
            "現在のデザインと類似しつつスタイルの異なるパネルバリエーションを生成してください。要件: \(prompt)\n\n機能は同じまま、配色、間隔、角丸などの視覚プロパティを調整し、3つのバリエーション案を生成してください。"
        },
        skillSpecDocPrompt: { prompt in
            "現在のデザインに基づき、設計仕様書を生成してください。含む内容:\n1. デザイン Token（色、フォント、間隔、角丸）\n2. コンポーネント仕様（ボタン、カード、入力欄など）\n3. レイアウトルール\n4. インタラクション状態仕様\n\n追加要件: \(prompt)"
        },
        pageFlowPerPage: { idx, name, prompt in
            "ページ\(idx+1)「\(name)」: \(prompt)"
        },
        pageFlowFlowPrompt: { flowDesc in
            "複数ページのフローを設計してください。以下のページ間のナビゲーション関係を含む:\n\(flowDesc)\n\n各ページに次ページへのナビゲーション要素（ボタン/リンク）を含めてください。"
        },
        pageFlowPagePrompt: { flowPrompt, idx, pageName in
            "\(flowPrompt)\n\n現在生成中: ページ\(idx+1)「\(pageName)」"
        },
        multiVariantsStyledPrompt: { prompt, style in
            "\(prompt)（スタイル：\(style)）"
        },
        sendDesignChatArtifactAppend: { currentArtifactCode in
            "\n\n現在のデザインコード:\n```html\n\(currentArtifactCode)\n```\nこのコードに基づいて反復修正を行ってください。"
        },
        sendDesignChatRagAppend: { rag in
            "\n\nプロジェクト設計仕様:\n\(rag)"
        }
    )
}
