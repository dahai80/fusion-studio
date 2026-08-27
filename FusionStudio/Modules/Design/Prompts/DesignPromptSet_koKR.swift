// F-I11: ko-KR locale prompt set — translated. Natural language translated,
// technical directives verbatim (antArtifact tag, CSS :root block, hex, JSON format, Tailwind/CDN/dark/HTML/React).

import Foundation

extension DesignPrompts {

    static let koKR = DesignPromptSet(
        systemPrompt: """
        당신은 Fusion Studio의 전문 UI 디자이너이자 프론트엔드 엔지니어입니다. 사용자 요구사항에 따라 고품질의 HTML 컴포넌트 코드를 생성하세요.

        ## 출력 사양

        1. Tailwind CSS (CDN)로 스타일링, 인라인 style 사용 안 함
        2. 컴포넌트는 자체 포함된 완전한 HTML 문서여야 하며, 브라우저에서 직접 실행 가능할 것
        3. dark 테마 지원 (기본 어두운 배경 #1a1a2e, 텍스트 #e0e0e0)
        4. 반응형 레이아웃, Tailwind의 responsive 접두사 사용
        5. 인터랙션 로직은 인라인 <script>로 구현
        6. 프레임워크 사용 안 함 (React/Vue/Angular), 순수 HTML + Tailwind + vanilla JS
        7. CSS 변수로 디자인 Token 정의:

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

        ## 출력 형식

        생성한 코드를 antArtifact 태그로 감싸세요:

        <antArtifact type="html" title="컴포넌트 이름">
        완전한 HTML 코드...
        </antArtifact>

        사용자가 기존 디자인 수정을 요청하면, 수정된 완전한 코드만 출력하세요 (여전히 antArtifact로 감쌈). diff는 출력하지 않습니다.
        코드 외의 추가 설명을 덧붙이지 마세요. 코드가 최종 산출물입니다.
        """,
        templatePrompts: [
            "login": "현대적인 로그인 페이지를 설계하세요. 어두운 테마, 이메일과 비밀번호 로그인 지원, \"로그인 상태 유지\" 옵션과 \"비밀번호 찾기\" 링크, 하단에 소셜 로그인 버튼",
            "dashboard": "데이터 대시보드 페이지를 설계하세요. 어두운 테마, 상단 내비게이션 바, 좌측 사이드바 메뉴, 메인 영역에 4개 데이터 카드 + 꺾은선 그래프 영역 + 데이터 테이블",
            "landing": "제품 랜딩 페이지를 설계하세요. 어두운 테마, 내비게이션 바, Hero 영역 (큰 제목 + 부제목 + CTA 버튼), 기능 소개 영역 (3열), 가격 영역 (3개 가격 카드), 푸터 포함",
            "settings": "설정 페이지를 설계하세요. 어두운 테마, 좌측 탭 내비게이션 (일반/보안/알림/외관), 우측에 해당 설정 내용, 폼 컨트롤 (스위치/셀렉터/입력란) 사용",
            "chat": "채팅 인터페이스를 설계하세요. 어두운 테마, 좌측 대화 목록, 우측 채팅 영역 (메시지 버블 + 입력란), 전송 버튼과 첨부 버튼 지원",
            "profile": "프로필 페이지를 설계하세요. 어두운 테마, 상단 아바타 + 이름 + 소개, 하단 탭 전환 (활동/즐겨찾기/소개), 카드 목록 표시",
            "card": "카드 컴포넌트 세트를 설계하세요: 표준 카드, 특집 카드 (이미지 포함), 아웃라인 카드, 각각 3가지 크기, Fusion Design Token 사용",
            "form": "회원가입 폼을 설계하세요. 어두운 테마, 사용자 이름, 이메일, 비밀번호 (강도 표시기 포함), 비밀번호 확인, 약관 동의 체크박스, 제출 버튼, 폼 검증 로직 포함",
            "table": "대화형 데이터 테이블 페이지를 설계하세요. 어두운 테마, 정렬, 검색 필터, 페이지네이션 지원, 각 행에 액션 버튼 (편집/삭제), 헤더 클릭 시 정렬 가능",
            "nav": "내비게이션 컴포넌트 세트를 설계하세요: 상단 내비게이션 바 (검색 + 사용자 아바타 포함), 사이드바 내비게이션 (접기 가능 + 아이콘 + 라벨), 브레드크럼 내비게이션, 어두운 테마",
            "modal": "모달 컴포넌트 세트를 설계하세요: 확인 대화상자, 폼 모달, 전체 화면 모달, 하단 서랍, 오버레이와 애니메이션 포함, 어두운 테마",
            "buttons": "버튼 컴포넌트 세트를 설계하세요: 주요/보조/아웃라인/텍스트/위험 버튼, 각각 기본/hover/active/disabled 상태 포함, 어두운 테마",
        ],
        pageFlowDefaultNames: ["홈", "목록", "상세"],
        multiVariantsDefaultStyles: ["심플", "모던", "미니멀"],
        fallbackTextToUI: "현대적인 어두운 테마 페이지를 설계하세요",
        fallbackImageToUIHint: "이미지를 참고하여 UI 레이아웃을 생성하세요",
        fallbackMultiVariants: "데이터 카드 컴포넌트를 설계하세요",
        fallbackLocalEditInstruction: "선택한 요소를 수정하세요",
        fallbackPartialEditInstruction: "선택한 노드의 시각적 스타일을 최적화하세요",
        fallbackSimPanel: "스타일 변형을 생성하세요",
        fallbackSpecDoc: "완전한 설계 사양서를 출력하세요",
        fallbackPageFlow: "홈 → 목록 → 상세 내비게이션 흐름",
        applyLocalEditContext: { nodesJSON, instruction in
            "선택한 노드의 현재 상태:\n\(nodesJSON)\n\n위 노드를 수정하여 다음을 충족하세요: \(instruction)\n\n수정된 노드의 JSON 배열만 출력하세요. 다른 내용은 출력하지 마세요. 형식: [{\"id\":\"...\", ...수정한 속성}]"
        },
        skillImageToUIPrompt: { imagePath, hint, pageName in
            "참고 이미지 경로: \(imagePath)\n추가 설명: \(hint)\n페이지 \"\(pageName)\"에 해당하는 UI 레이아웃을 생성하세요"
        },
        skillPartialEditPrompt: { nodesJSON, instruction in
            "다음 노드에 부분 수정을 수행하세요:\n\(nodesJSON)\n\n수정 요구사항: \(instruction)\n\n수정된 노드의 완전한 JSON만 출력하세요. id는 변경하지 마세요. 형식: [{\"id\":\"...\", ...모든 속성}]"
        },
        skillSimPanelPrompt: { prompt in
            "현재 디자인과 유사하지만 스타일이 다른 패널 변형을 생성하세요. 요구사항: \(prompt)\n\n기능은 동일하게 유지하되, 색상, 간격, 모서리 반경 등 시각적 속성을 조정하여 3가지 변형안을 제출하세요."
        },
        skillSpecDocPrompt: { prompt in
            "현재 디자인을 기반으로 설계 사양서를 생성하세요. 포함 내용:\n1. 디자인 Token (색상, 글꼴, 간격, 모서리 반경)\n2. 컴포넌트 사양 (버튼, 카드, 입력란 등)\n3. 레이아웃 규칙\n4. 인터랙션 상태 사양\n\n추가 요구사항: \(prompt)"
        },
        pageFlowPerPage: { idx, name, prompt in
            "페이지 \(idx+1) \"\(name)\": \(prompt)"
        },
        pageFlowFlowPrompt: { flowDesc in
            "여러 페이지의 흐름을 설계하세요. 다음 페이지 간의 내비게이션 관계를 포함:\n\(flowDesc)\n\n각 페이지에는 다음 페이지를 가리키는 내비게이션 요소 (버튼/링크)를 포함하세요."
        },
        pageFlowPagePrompt: { flowPrompt, idx, pageName in
            "\(flowPrompt)\n\n현재 생성 중: 페이지 \(idx+1) \"\(pageName)\""
        },
        multiVariantsStyledPrompt: { prompt, style in
            "\(prompt) (스타일: \(style))"
        },
        sendDesignChatArtifactAppend: { currentArtifactCode in
            "\n\n현재 디자인 코드:\n```html\n\(currentArtifactCode)\n```\n이 코드를 기반으로 반복 수정하세요."
        },
        sendDesignChatRagAppend: { rag in
            "\n\n프로젝트 설계 사양:\n\(rag)"
        }
    )
}
