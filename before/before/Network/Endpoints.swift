//
//  Endpoints.swift
//  before
//
//  ZERi-client/src/apis/endpoints.ts 의 Swift 미러.
//  모든 path 는 slash 없는 형태 (백엔드 라우터와 일치).
//

import Foundation

enum Endpoints {
    enum Auth {
        static let signup = "/v1/auth/signup"
        static let login = "/v1/auth/login"
        static let refresh = "/v1/auth/refresh"
        static let logout = "/v1/auth/logout"
    }

    enum Me {
        static let profile = "/v1/me"
        static let disclaimerAck = "/v1/me/disclaimer-ack"
        static let watchlist = "/v1/me/watchlist"
        static func watchlistItem(_ ticker: String) -> String { "/v1/me/watchlist/\(ticker)" }
        static let history = "/v1/me/history"
        static let historyStats = "/v1/me/history/stats"
        static func historyItem(_ analysisId: Int) -> String { "/v1/me/history/\(analysisId)" }
    }

    enum Risk {
        static let spotlight = "/v1/risk/spotlight"
        static func verdict(_ ticker: String) -> String { "/v1/risk/\(ticker)" }
        static func path(_ ticker: String) -> String { "/v1/risk/\(ticker)/path" }
        static func attention(_ ticker: String) -> String { "/v1/risk/\(ticker)/attention" }
        static func predictions(_ ticker: String) -> String { "/v1/risk/\(ticker)/predictions" }
    }

    enum Tickers {
        static let list = "/v1/tickers"
        static let search = "/v1/tickers/search"
    }

    enum Prices {
        static func latest(_ target: String) -> String { "/v1/prices/\(target)" }
        static func history(_ ticker: String) -> String { "/v1/prices/\(ticker)/history" }
    }

    enum Macro {
        static func series(_ code: String) -> String { "/v1/macro/\(code)" }
    }
}
