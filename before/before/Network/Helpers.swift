//
//  Helpers.swift
//  before
//
//  백엔드 응답 (Decimal-as-String) ↔ UI (Double) 변환 헬퍼.
//

import Foundation

extension String {
    /// "-0.2200" → -0.22
    var asDouble: Double { Double(self) ?? 0 }
}

extension Optional where Wrapped == String {
    var asDouble: Double { (self ?? "0").asDouble }
}

extension SpotlightItem {
    var worstCaseDouble: Double { worstCasePct.asDouble }
    var priceDoubleString: String { currentPrice.flatMap { "$\($0)" } ?? "—" }
}

extension RiskVerdictData {
    var worstCaseDouble: Double { grade.worstCasePct.asDouble }
    var priceDisplay: String { currentPrice.flatMap { "$\($0)" } ?? "—" }
}
