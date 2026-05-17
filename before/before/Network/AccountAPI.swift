//
//  AccountAPI.swift
//  before
//
//  /v1/me, /v1/me/watchlist, /v1/me/history wrapper.
//  대부분 인증 필요 — 토큰 만료 시 HTTPClient 가 onUnauthorized 트리거.
//

import Foundation

// MARK: - Me

enum MeAPI {
    /// 현재 로그인 사용자 프로필.
    static func profile() async throws -> UserPublic {
        let res: MeResponse = try await HTTPClient.shared.get(Endpoints.Me.profile)
        return res.user
    }

    /// 면책 동의 기록 (재동의 시 새 행 INSERT).
    struct DisclaimerAckRequest: Encodable, Sendable {
        let disclaimerCode: String

        enum CodingKeys: String, CodingKey {
            case disclaimerCode = "disclaimer_code"
        }
    }

    struct DisclaimerAckData: Decodable, Sendable {
        let ackId: Int
        let disclaimerCode: String
        let acknowledgedAt: String

        enum CodingKeys: String, CodingKey {
            case ackId = "ack_id"
            case disclaimerCode = "disclaimer_code"
            case acknowledgedAt = "acknowledged_at"
        }
    }

    @discardableResult
    static func acknowledgeDisclaimer(code: String = "MAIN_V1") async throws -> DisclaimerAckData {
        let req = DisclaimerAckRequest(disclaimerCode: code)
        return try await HTTPClient.shared.post(Endpoints.Me.disclaimerAck, body: req)
    }
}

// MARK: - Watchlist

enum WatchlistAPI {
    /// 내 워치리스트 (최신 추가 순).
    static func list() async throws -> WatchlistData {
        try await HTTPClient.shared.get(Endpoints.Me.watchlist)
    }

    struct AddWatchlistRequest: Encodable, Sendable {
        let ticker: String
    }

    struct AddWatchlistData: Decodable, Sendable {
        let item: WatchlistItem
    }

    /// 워치리스트에 종목 추가 (한도 100개).
    static func add(ticker: String) async throws -> WatchlistItem {
        let req = AddWatchlistRequest(ticker: ticker)
        let res: AddWatchlistData = try await HTTPClient.shared.post(
            Endpoints.Me.watchlist, body: req
        )
        return res.item
    }

    struct DeleteWatchlistData: Decodable, Sendable {
        let deleted: Bool
        let ticker: String
    }

    /// 워치리스트에서 종목 삭제 (멱등).
    @discardableResult
    static func remove(ticker: String) async throws -> Bool {
        let res: DeleteWatchlistData = try await HTTPClient.shared.delete(
            Endpoints.Me.watchlistItem(ticker)
        )
        return res.deleted
    }
}

// MARK: - History

struct HistoryItem: Decodable, Sendable, Identifiable {
    var id: Int { analysisId }
    let analysisId: Int
    let ticker: String
    let companyNameKr: String?
    let grade: String
    let worstCasePct: String?
    let priceAtQuery: String
    let queriedAt: String
    let outcome: String?              // "price_dropped" / "price_rose" / "flat" / null
    let outcomePct: String?
    let outcomeEvaluatedAt: String?

    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case ticker
        case companyNameKr = "company_name_kr"
        case grade
        case worstCasePct = "worst_case_pct"
        case priceAtQuery = "price_at_query"
        case queriedAt = "queried_at"
        case outcome
        case outcomePct = "outcome_pct"
        case outcomeEvaluatedAt = "outcome_evaluated_at"
    }
}

struct HistoryListData: Decodable, Sendable {
    let items: [HistoryItem]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

struct HistoryStatsData: Decodable, Sendable {
    let totalAnalyses: Int
    let byOutcome: [String: Int]
    let byGradeOutcome: [String: [String: Int]]

    enum CodingKeys: String, CodingKey {
        case totalAnalyses = "total_analyses"
        case byOutcome = "by_outcome"
        case byGradeOutcome = "by_grade_outcome"
    }
}

struct HistoryDetailData: Decodable, Sendable {
    let item: HistoryItem
}

enum HistoryAPI {
    /// 분석 기록 페이지네이션.
    /// outcome: "price_dropped" / "price_rose" / "flat" / "pending" / nil
    /// grade: "VOLATILITY_HIGH" / "VOLATILITY_MID" / "VOLATILITY_LOW" / nil
    static func list(
        cursor: String? = nil,
        limit: Int = 20,
        grade: String? = nil,
        outcome: String? = nil
    ) async throws -> HistoryListData {
        var q: [String: String] = ["limit": String(limit)]
        if let c = cursor { q["cursor"] = c }
        if let g = grade { q["grade"] = g }
        if let o = outcome { q["outcome"] = o }
        return try await HTTPClient.shared.get(Endpoints.Me.history, query: q)
    }

    static func stats() async throws -> HistoryStatsData {
        try await HTTPClient.shared.get(Endpoints.Me.historyStats)
    }

    static func detail(analysisId: Int) async throws -> HistoryDetailData {
        try await HTTPClient.shared.get(Endpoints.Me.historyItem(analysisId))
    }
}
