# ZERi

> 매수 직전 60초.
> 30일 안에 일어날 수 있는 최악을 보여주는 iOS 앱.

<br>

ZERi 는 자본시장법상 투자자문업이 아닙니다. 통계 모델 기반의 정보 제공 서비스이며, 매수·매도를 권유하지 않습니다.

<br>

---

## 무엇을 하나

50개 미국 상장 종목에 대해, 통계 모델이 추정한 **30일 내 최악의 하락 시나리오** 를 시각화합니다. 매수를 부추기는 모든 앱의 반대편을 지향합니다.

- 30일 분위수 경로 (Q05 / Q15)
- 핵심 영향 변수 Top 3 (XAI)
- 과거 30일 실제 종가 + 미래 30일 예측 통합 차트
- 워치리스트 / 분석 기록 / 위험도 변화 알림

<br>

---

## 화면

| 화면 | 역할 |
|---|---|
| **Splash** | 0.5s 진입, 토큰 확인 |
| **Onboarding** | 첫 진입 안내 (1회) |
| **Terms Gate** | 약관·면책 동의 (필수, 1회) |
| **Home** | 위험 spotlight + 워치리스트 |
| **Search** | 50종목 검색 (디바운스 자동완성) |
| **Verdict** | 종목 분석 결과 (Layer 1·2·3 구조) |
| **History** | 분석 기록 + D+30 outcome |
| **My Page** | 프로필 · 통계 · 알림 · 약관 이력 |

<br>

---

## 아키텍처

```
ZERi-ios
├── before/
│   ├── before.xcodeproj
│   └── before/
│       ├── AppRoot.swift           # 라우팅 + AppState
│       ├── Network/                # API · HTTP · Keychain
│       │   ├── HTTPClient.swift
│       │   ├── TokenStore.swift    # Keychain JWT
│       │   ├── AuthAPI.swift
│       │   ├── RiskAPI.swift
│       │   ├── PricesAPI.swift     # (RiskAPI.swift 안)
│       │   ├── MeAPI / WatchlistAPI / HistoryAPI / TickersAPI
│       │   └── Models.swift        # Decodable
│       ├── Views/
│       │   ├── HomeView.swift
│       │   ├── SearchView.swift
│       │   ├── VerdictView.swift   # 메인 결과 화면
│       │   ├── RiskMainChart.swift # 통합 fan chart (Swift Charts)
│       │   ├── HistoryView.swift
│       │   ├── MyPageView.swift
│       │   ├── AuthView.swift      # Apple 스타일
│       │   ├── TermsGateView.swift # 약관 동의
│       │   ├── TermsContent.swift  # 약관 본문
│       │   ├── TermsHistoryView.swift
│       │   ├── NotificationSettingsView.swift
│       │   ├── WatchlistManageView.swift
│       │   ├── OnboardingView.swift
│       │   ├── SplashView.swift
│       │   ├── Components.swift    # 공통 컴포넌트
│       │   └── Theme.swift         # Color Asset 가이드
│       ├── Assets.xcassets/
│       │   ├── BrandPrimary.colorset
│       │   ├── BrandOnPrimary.colorset
│       │   ├── RiskRed.colorset
│       │   ├── RiskRedSoft.colorset
│       │   ├── TrendUp.colorset
│       │   └── AccentColor.colorset   # 모두 light + dark 변형
│       └── Info.plist
└── README.md
```

<br>

---

## 기술 스택

- **SwiftUI** · iOS 17+
- **Swift Charts** — 통합 fan chart
- **async/await** — 비동기 네트워크
- **Keychain** — JWT 토큰 안전 보관
- **UserDefaults** — onboarding · terms · 알림 설정 영속화
- **Color Asset Catalog** — 라이트/다크 자동 적응

<br>

---

## 빌드

요구사항: **Xcode 15+**, **iOS 17.0+** 디바이스 또는 시뮬레이터.

```bash
git clone https://github.com/JusikCool/ZERi-ios.git
cd ZERi-ios
open before/before.xcodeproj
```

Xcode 에서 `Cmd + R`. 별도 의존성 / SPM 패키지 없음.

<br>

---

## 백엔드 연결

기본 API base URL: `https://jusikcool.duckdns.org`

다른 환경으로 바꾸려면 `Info.plist` 의 `API_BASE_URL` 키:

```xml
<key>API_BASE_URL</key>
<string>https://your-backend.example</string>
```

또는 `Network/APIConfig.swift` 의 fallback 값 수정.

백엔드 API 명세는 [ZERi-server](https://github.com/JusikCool/ZERi-server) 참조.

<br>

---

## 다크모드

모든 색상이 Asset Catalog 기반으로 자동 적응. 시뮬레이터에서:

`Cmd + Shift + A` (시뮬레이터 Features → Toggle Appearance)

<br>

---

## 디자인 원칙

1. 매수를 부추기지 않는다 — 매수/매도 버튼 없음
2. 목표가 없음 — 분위수 분포만 노출
3. 상방을 주인공으로 만들지 않음 — 빨강이 메인
4. FOMO 장치 (인기 종목, 커뮤니티) 없음
5. 실시간 호가 / 차트 없음 — 그건 증권사 일

<br>

---

## License

내부 발표 / 평가 목적. 외부 배포 전 면책·약관 법무 검토 필수.

<br>

---

ZERi · 통계 모델 기반 위험 정보 서비스
