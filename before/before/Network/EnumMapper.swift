//
//  EnumMapper.swift
//  before
//
//  백엔드 enum 코드 → 한국어 라벨.
//  ZERi-client/src/apis/enumMapper.ts 의 Swift 미러.
//

import Foundation

enum GradeLabel {
    private static let map: [String: String] = [
        "VOLATILITY_HIGH": "높음",
        "VOLATILITY_MID": "중간",
        "VOLATILITY_LOW": "보통",
    ]
    static func label(_ grade: String) -> String { map[grade] ?? grade }
}

enum OutcomeLabel {
    private static let map: [String: String] = [
        "price_dropped": "하락",
        "price_rose": "상승",
        "flat": "보합",
        "pending": "평가 중",
    ]
    static func label(_ outcome: String) -> String { map[outcome] ?? outcome }
}

enum HeadlineLabel {
    private static let map: [String: String] = [
        "HIGH_RISK_FOUND": "위험 신호",
        "ALL_QUIET": "안정",
    ]
    static func label(_ code: String) -> String { map[code] ?? code }
}
