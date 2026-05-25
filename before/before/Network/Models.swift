//
//  Models.swift
//  before
//
//  백엔드 응답 DTO 의 Swift Codable 미러.
//  ZERi-client/src/apis/types.ts 대응. 필요한 만큼만 채워두고 추후 확장.
//

import Foundation

// MARK: - Auth

struct UserPublic: Decodable, Sendable {
    let userId: Int
    let email: String
    let name: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case name
        case createdAt = "created_at"
    }
}

struct TokenPair: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessExpiresAt: String
    let refreshExpiresAt: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case accessExpiresAt = "access_expires_at"
        case refreshExpiresAt = "refresh_expires_at"
    }
}

struct SignupResponse: Decodable, Sendable {
    let user: UserPublic
    let tokens: TokenPair
}

struct LoginResponse: Decodable, Sendable {
    let user: UserPublic
    let tokens: TokenPair
}

struct RefreshResponse: Decodable, Sendable {
    let tokens: TokenPair
}

struct LogoutResponse: Decodable, Sendable {
    let revoked: Bool
}

struct SignupRequest: Encodable, Sendable {
    let email: String
    let password: String
    let name: String
    let disclaimerCode: String

    enum CodingKeys: String, CodingKey {
        case email, password, name
        case disclaimerCode = "disclaimer_code"
    }
}

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Me

struct MeResponse: Decodable, Sendable {
    let user: UserPublic
}

// MARK: - Risk

struct RiskGradeSection: Decodable, Sendable {
    let value: String                  // VOLATILITY_HIGH/MID/LOW
    let worstCasePct: String           // Decimal string e.g. "-0.2200"
    let messageCode: String

    enum CodingKeys: String, CodingKey {
        case value
        case worstCasePct = "worst_case_pct"
        case messageCode = "message_code"
    }
}

struct RiskPredictionSection: Decodable, Sendable {
    let predictionId: Int
    let baseDate: String
    let horizonDays: Int
    let q05Path: [Double]
    let q15Path: [Double]
    let modelName: String
    let modelVersion: String

    enum CodingKeys: String, CodingKey {
        case predictionId = "prediction_id"
        case baseDate = "base_date"
        case horizonDays = "horizon_days"
        case q05Path = "q05_path"
        case q15Path = "q15_path"
        case modelName = "model_name"
        case modelVersion = "model_version"
    }
}

struct RiskXaiFeature: Decodable, Sendable, Identifiable {
    var id: String { feature }
    let feature: String
    let weight: Double
    let label: String
    let description: String?
    /// 보조 지표 라벨 (예: "최근 10일 실현 변동성")
    let auxLabel: String?
    /// 보조 지표 값 (예: "평소 대비 2.3배")
    let auxValue: String?
    /// 해석 — 모델 입력 기반 의미 (rule-based 또는 LLM summary)
    let interpretation: String?
    /// 사용자가 함께 확인할 것 (행동 안내)
    let actionHint: String?

    enum CodingKeys: String, CodingKey {
        case feature, weight, label, description
        case auxLabel = "aux_label"
        case auxValue = "aux_value"
        case interpretation
        case actionHint = "action_hint"
    }
}

/// 백테스트 기반 신뢰 평가 (Coverage / Kupiec test 결과)
struct RiskXaiBacktest: Decodable, Sendable {
    let coveragePct: Double?       // 0.91 → 91%
    let kupiecPass: Bool?

    enum CodingKeys: String, CodingKey {
        case coveragePct = "coverage_pct"
        case kupiecPass = "kupiec_pass"
    }
}

struct RiskXaiSection: Decodable, Sendable {
    let features: [RiskXaiFeature]
    /// 요약 카드 하단 행동 가이드 (rule-based)
    let actionGuide: String?
    /// 백테스트 기반 신뢰 평가
    let backtest: RiskXaiBacktest?

    enum CodingKeys: String, CodingKey {
        case features
        case actionGuide = "action_guide"
        case backtest
    }
}

struct RiskVerdictData: Decodable, Sendable {
    let ticker: String
    let companyNameKr: String?
    let currentPrice: String?
    let asOf: String
    let grade: RiskGradeSection
    let prediction: RiskPredictionSection
    let xai: RiskXaiSection?
    let summaryNarrative: String?
    /// Upstage Solar 가 정제한 풀어쓴 한 단락 설명. 매일 cron 갱신.
    /// 미존재 시 nil — 화면은 summaryNarrative 로 폴백.
    let detailedNarrative: String?
    /// detailedNarrative 가 기반한 추론 기준일자 (ISO yyyy-MM-dd).
    /// asOf 와 다르면 cron 실패로 며칠 묵은 상태.
    let detailedNarrativeBaseDate: String?
    let analysisId: Int?

    enum CodingKeys: String, CodingKey {
        case ticker
        case companyNameKr = "company_name_kr"
        case currentPrice = "current_price"
        case asOf = "as_of"
        case grade, prediction, xai
        case summaryNarrative = "summary_narrative"
        case detailedNarrative = "detailed_narrative"
        case detailedNarrativeBaseDate = "detailed_narrative_base_date"
        case analysisId = "analysis_id"
    }
}

struct RiskPathData: Decodable, Sendable {
    let ticker: String
    let baseDate: String
    let horizonDays: Int
    let q05Path: [Double]
    let q15Path: [Double]
    /// 전체 19개 분위수 — {"0.05": [..30..], "0.10": [...], ..., "0.95": [...]}
    let quantilePaths: [String: [Double]]?

    enum CodingKeys: String, CodingKey {
        case ticker
        case baseDate = "base_date"
        case horizonDays = "horizon_days"
        case q05Path = "q05_path"
        case q15Path = "q15_path"
        case quantilePaths = "quantile_paths"
    }
}

struct RiskAttentionData: Decodable, Sendable {
    let ticker: String
    let baseDate: String
    let features: [RiskXaiFeature]
    let actionGuide: String?
    let backtest: RiskXaiBacktest?

    enum CodingKeys: String, CodingKey {
        case ticker
        case baseDate = "base_date"
        case features
        case actionGuide = "action_guide"
        case backtest
    }
}

// MARK: - Price History (메인 차트 좌측 — 과거 N일 종가)

struct HistoricalPriceItem: Decodable, Sendable, Identifiable {
    let tradeDate: String   // "2026-05-17"
    let close: Double
    var id: String { tradeDate }

    enum CodingKeys: String, CodingKey {
        case tradeDate = "trade_date"
        case close
    }
}

struct HistoricalPricesData: Decodable, Sendable {
    let ticker: String
    let days: Int
    let items: [HistoricalPriceItem]   // 오래된 → 최근 순
}

// MARK: - Spotlight

struct SpotlightItem: Decodable, Sendable {
    let ticker: String
    let companyNameKr: String?
    let grade: String
    let messageCode: String
    let worstCasePct: String
    let currentPrice: String?
    let asOf: String

    enum CodingKeys: String, CodingKey {
        case ticker
        case companyNameKr = "company_name_kr"
        case grade
        case messageCode = "message_code"
        case worstCasePct = "worst_case_pct"
        case currentPrice = "current_price"
        case asOf = "as_of"
    }
}

struct SpotlightData: Decodable, Sendable {
    let spotlight: SpotlightItem?
    let headlineCode: String

    enum CodingKeys: String, CodingKey {
        case spotlight
        case headlineCode = "headline_code"
    }
}

// MARK: - Tickers

struct TickerSearchItem: Decodable, Sendable, Identifiable {
    var id: String { ticker }
    let ticker: String
    let companyName: String
    let companyNameKr: String?
    let sector: String?
    let marketCap: Int?

    enum CodingKeys: String, CodingKey {
        case ticker
        case companyName = "company_name"
        case companyNameKr = "company_name_kr"
        case sector
        case marketCap = "market_cap"
    }
}

struct TickerSearchData: Decodable, Sendable {
    let query: String
    let count: Int
    let items: [TickerSearchItem]
}

// MARK: - Watchlist (간단 버전)

struct WatchlistItem: Decodable, Sendable, Identifiable {
    var id: String { ticker }
    let ticker: String
    let companyName: String
    let companyNameKr: String?
    let sector: String?
    let marketCap: Int?
    let isActive: Bool
    let addedAt: String

    enum CodingKeys: String, CodingKey {
        case ticker
        case companyName = "company_name"
        case companyNameKr = "company_name_kr"
        case sector
        case marketCap = "market_cap"
        case isActive = "is_active"
        case addedAt = "added_at"
    }
}

struct WatchlistData: Decodable, Sendable {
    let count: Int
    let items: [WatchlistItem]
}
