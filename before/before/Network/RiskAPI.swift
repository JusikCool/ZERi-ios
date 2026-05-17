//
//  RiskAPI.swift
//  before
//
//  Risk 도메인 GET 엔드포인트 wrapper.
//

import Foundation

enum RiskAPI {
    /// 홈 — 오늘의 한 종목 (HIGH 등급 중 worst_case 최상위).
    /// scope = "all" (기본) 또는 "watchlist" (인증 필요).
    static func spotlight(scope: String = "all") async throws -> SpotlightData {
        try await HTTPClient.shared.get(Endpoints.Risk.spotlight, query: ["scope": scope])
    }

    /// 단일 종목 종합 — grade + prediction + xai + summary_narrative.
    /// record=true + 인증 시 analysis_history INSERT.
    static func verdict(ticker: String, record: Bool = false) async throws -> RiskVerdictData {
        try await HTTPClient.shared.get(
            Endpoints.Risk.verdict(ticker),
            query: ["record": record ? "true" : "false"]
        )
    }

    /// fan chart 용 q05/q15 path.
    static func path(ticker: String) async throws -> RiskPathData {
        try await HTTPClient.shared.get(Endpoints.Risk.path(ticker))
    }

    /// XAI top-3 변수 + 자연어 설명.
    static func attention(ticker: String) async throws -> RiskAttentionData {
        try await HTTPClient.shared.get(Endpoints.Risk.attention(ticker))
    }

    /// 티커별 전체 예측 이력 — base_date 내림차순 (최신 → 과거).
    /// backtest / Trust Audit 페이지용. 출시 직후엔 1건만 반환, 매일 1건씩 누적.
    static func predictionsHistory(ticker: String, limit: Int = 100) async throws -> PredictionHistoryData {
        try await HTTPClient.shared.get(
            Endpoints.Risk.predictions(ticker),
            query: ["limit": String(limit)]
        )
    }
}

/// 가격 도메인 — 과거 N일 종가 (DB 조회, yfinance 미호출).
enum PricesAPI {
    /// 메인 차트 좌측 (과거 컨텍스트) 용. items 는 오래된 → 최근 순.
    static func history(ticker: String, days: Int = 30) async throws -> HistoricalPricesData {
        try await HTTPClient.shared.get(
            Endpoints.Prices.history(ticker),
            query: ["days": String(days)]
        )
    }
}

// MARK: - Prediction history models

struct PredictionHistoryItem: Decodable, Sendable, Identifiable {
    let baseDate: String
    let horizonDays: Int
    let q05Path: [Double]
    let q15Path: [Double]
    let quantilePaths: [String: [Double]]?
    let worstCasePct: Double?
    let modelName: String
    let modelVersion: String

    var id: String { baseDate }

    enum CodingKeys: String, CodingKey {
        case baseDate = "base_date"
        case horizonDays = "horizon_days"
        case q05Path = "q05_path"
        case q15Path = "q15_path"
        case quantilePaths = "quantile_paths"
        case worstCasePct = "worst_case_pct"
        case modelName = "model_name"
        case modelVersion = "model_version"
    }
}

struct PredictionHistoryData: Decodable, Sendable {
    let ticker: String
    let count: Int
    let items: [PredictionHistoryItem]
}

enum TickersAPI {
    /// 활성 종목 전체 리스트.
    struct TickerLite: Decodable, Sendable, Identifiable {
        var id: String { ticker }
        let ticker: String
        let companyName: String
        let companyNameKr: String?
        let sector: String?

        enum CodingKeys: String, CodingKey {
            case ticker
            case companyName = "company_name"
            case companyNameKr = "company_name_kr"
            case sector
        }
    }

    struct TickerListData: Decodable, Sendable {
        let count: Int
        let items: [TickerLite]
    }

    static func list() async throws -> TickerListData {
        try await HTTPClient.shared.get(Endpoints.Tickers.list)
    }

    /// 자동완성 검색 — 티커 / 한글명 / 영문명.
    static func search(query q: String, limit: Int = 10) async throws -> TickerSearchData {
        try await HTTPClient.shared.get(
            Endpoints.Tickers.search,
            query: ["q": q, "limit": String(limit)]
        )
    }
}
