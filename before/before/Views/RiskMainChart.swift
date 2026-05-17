//
//  RiskMainChart.swift
//  before
//
//  기획서 Layer 2 — 메인 차트.
//  과거 30일 실제 종가 (회색 선) + 미래 30일 Q05/Q15 fan (빨강) + 오늘 기준선 + 최악값 라벨.
//
//  Y 축: 현재가 대비 % 변화율.
//    과거 ⇢ (close[i] - currentPrice) / currentPrice
//    미래 ⇢ Q05/Q15 path 그대로 (이미 비율)
//
//  X 축: -30 ~ +30 거래일. 0 = 오늘.
//

import SwiftUI
import Charts

struct RiskMainChart: View {
    let pastPrices: [HistoricalPriceItem]   // 오래된 → 최근
    let q05: [Double]                       // 미래 30일
    let q15: [Double]
    let currentPrice: Double
    let worstCasePct: Double                // 라벨용

    @State private var selectedDay: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
            legend
        }
    }

    private var chart: some View {
        let past = pastReturns()           // (day, return) — day in -N...0
        let pastCount = past.count
        let n = min(q05.count, q15.count)

        // 미래 라인을 (0, 0%) 에서 출발시키기 위해 day 0 을 prepend.
        // 결과 길이 = n+1, index 0 → (day=0, value=0), index i (1...n) → (day=i, value=q[i-1])
        let q05Pts: [(day: Int, value: Double)] =
            [(0, 0.0)] + (0..<n).map { (i: Int) in (i + 1, q05[i]) }
        let q15Pts: [(day: Int, value: Double)] =
            [(0, 0.0)] + (0..<n).map { (i: Int) in (i + 1, q15[i]) }
        let futureCount = n

        return Chart {
            // ── 과거 종가 (회색 라인)
            ForEach(past, id: \.day) { p in
                LineMark(
                    x: .value("Day", p.day),
                    y: .value("Return", p.value),
                    series: .value("S", "past")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }

            // ── Q15 까지 음영 (옅은 빨강) — day 0 에서 출발
            ForEach(q15Pts, id: \.day) { p in
                AreaMark(
                    x: .value("Day", p.day),
                    yStart: .value("Q15", p.value),
                    yEnd: .value("Zero", 0.0)
                )
                .foregroundStyle(Color.red.opacity(0.08))
                .interpolationMethod(.monotone)
            }

            // ── Q05 까지 진한 음영
            ForEach(0...futureCount, id: \.self) { i in
                AreaMark(
                    x: .value("Day", q05Pts[i].day),
                    yStart: .value("Q05", q05Pts[i].value),
                    yEnd: .value("Q15", q15Pts[i].value)
                )
                .foregroundStyle(Color.red.opacity(0.18))
                .interpolationMethod(.monotone)
            }

            // ── Q05 라인 (진한 빨강) — day 0 에서 출발
            ForEach(q05Pts, id: \.day) { p in
                LineMark(
                    x: .value("Day", p.day),
                    y: .value("Q05", p.value),
                    series: .value("S", "q05")
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            // ── Q15 라인 (옅은 빨강 + 점선) — day 0 에서 출발
            ForEach(q15Pts, id: \.day) { p in
                LineMark(
                    x: .value("Day", p.day),
                    y: .value("Q15", p.value),
                    series: .value("S", "q15")
                )
                .foregroundStyle(Color.red.opacity(0.65))
                .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
                .interpolationMethod(.monotone)
            }

            // ── 오늘 기준선 (세로 점선)
            RuleMark(x: .value("Today", 0))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .center) {
                    Text("오늘")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemBackground))
                        .foregroundStyle(.secondary)
                }

            // ── 0% baseline
            RuleMark(y: .value("Baseline", 0.0))
                .foregroundStyle(Color.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.5))

            // ── 최악값 (Q05 끝점) 강조 + 라벨
            if futureCount > 0 {
                PointMark(
                    x: .value("Day", futureCount),
                    y: .value("Worst", q05[futureCount - 1])
                )
                .foregroundStyle(.red)
                .symbolSize(80)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text(String(format: "%.1f%%", worstCasePct * 100))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // ── 선택 마커 (탭 시)
            if let day = selectedDay {
                RuleMark(x: .value("Selected", day))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%+.0f%%", v * 100)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues(pastCount: pastCount, futureCount: futureCount)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.10))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(xLabel(v)).font(.caption2)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDay)
        .frame(height: 240)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(color: .secondary, label: "과거 종가", dashed: false)
            legendDot(color: .red, label: "Q05 (최악)", dashed: false)
            legendDot(color: .red.opacity(0.65), label: "Q15 (보수)", dashed: true)
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(color).frame(width: 14, height: 2)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    /// 과거 종가를 현재가 대비 % 변화율로 변환. day 는 음수 (-N ... 0).
    private func pastReturns() -> [(day: Int, value: Double)] {
        guard currentPrice > 0, !pastPrices.isEmpty else { return [] }
        let n = pastPrices.count
        return pastPrices.enumerated().map { (i, item) in
            let day = -(n - 1 - i)   // 가장 최근 = 0, 가장 과거 = -(n-1)
            let ret = (item.close - currentPrice) / currentPrice
            return (day, ret)
        }
    }

    private func xAxisValues(pastCount: Int, futureCount: Int) -> [Int] {
        let pastSteps = stride(from: -((pastCount - 1) / 5) * 5, through: 0, by: 5)
        let futureSteps = stride(from: 5, through: futureCount, by: 5)
        return Array(pastSteps) + Array(futureSteps)
    }

    private func xLabel(_ day: Int) -> String {
        if day == 0 { return "0" }
        if day < 0 { return "\(day)" }
        return "+\(day)"
    }
}
