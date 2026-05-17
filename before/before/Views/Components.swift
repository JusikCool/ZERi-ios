//
//  Components.swift
//  before
//
//  공용 작은 컴포넌트들. RiskBadge, WorstCaseCard, FanChartLite 등.
//  iOS native 느낌으로 — SF Symbols + 기본 system color + corner radius.
//

import SwiftUI

// MARK: - Grade → 색·라벨 헬퍼

enum GradeStyle {
    static func color(_ grade: String) -> Color {
        switch grade {
        case "VOLATILITY_HIGH": return .red
        case "VOLATILITY_MID": return .orange
        case "VOLATILITY_LOW": return Color(.systemGreen)
        default: return .secondary
        }
    }
    static func label(_ grade: String) -> String {
        switch grade {
        case "VOLATILITY_HIGH": return "높음"
        case "VOLATILITY_MID": return "중간"
        case "VOLATILITY_LOW": return "보통"
        default: return grade
        }
    }
    static func dotSize(_ grade: String) -> CGFloat { 8 }
}

// MARK: - Risk Badge — 등급 표시 작은 알약

struct RiskBadge: View {
    let grade: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(GradeStyle.color(grade))
                .frame(width: 6, height: 6)
            Text(GradeStyle.label(grade))
                .font(compact ? .caption2 : .caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(GradeStyle.color(grade).opacity(0.12))
        .foregroundStyle(GradeStyle.color(grade))
        .clipShape(Capsule())
    }
}

// MARK: - Worst Case Card — 큰 % 표시 카드

struct WorstCaseCard: View {
    let grade: String
    let worstCasePct: Double           // e.g. -0.22
    let subtitle: String                // 예: "30일 통계 모델 결과"

    private var pctText: String {
        String(format: "%.1f%%", worstCasePct * 100)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                RiskBadge(grade: grade)
            }
            Text("과거 데이터 기반 30일 변동성 추정")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(pctText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(Color.riskRed)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("과거 유사 변동성 구간의 통계적 추정치입니다.\n특정 가격을 예측하거나 보장하지 않습니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Fan Chart (Swift Charts 기반 · 줌 / 스크롤 / 탭으로 값 확인)

import Charts

struct FanChartLite: View {
    let q05: [Double]
    let q15: [Double]

    @State private var selectedDay: Int?
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    private var dayCount: Int { min(q05.count, q15.count) }

    /// 현재 보이는 일 수 — zoom 1x = 전체, 2x = 절반, 최대 4x = 1/4
    private var visibleDays: Double {
        let total = max(Double(dayCount), 1)
        return max(total / Double(zoomScale), 4)
    }

    var body: some View {
        VStack(spacing: 6) {
            chart
            hint
        }
    }

    private var chart: some View {
        Chart {
            // Q15 까지의 밴드 (옅음)
            ForEach(0..<dayCount, id: \.self) { i in
                AreaMark(
                    x: .value("Day", i + 1),
                    yStart: .value("Q15", q15[i]),
                    yEnd: .value("Zero", 0.0)
                )
                .foregroundStyle(Color.red.opacity(0.08))
                .interpolationMethod(.monotone)
            }

            // Q05 ~ Q15 사이 밴드 (조금 진함)
            ForEach(0..<dayCount, id: \.self) { i in
                AreaMark(
                    x: .value("Day", i + 1),
                    yStart: .value("Q05", q05[i]),
                    yEnd: .value("Q15", q15[i])
                )
                .foregroundStyle(Color.red.opacity(0.15))
                .interpolationMethod(.monotone)
            }

            // Q05 라인 (진한 빨강, 굵게)
            ForEach(0..<dayCount, id: \.self) { i in
                LineMark(
                    x: .value("Day", i + 1),
                    y: .value("Q05", q05[i]),
                    series: .value("S", "Q05")
                )
                .foregroundStyle(Color.riskRed)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            // Q15 라인 (옅은 빨강, 점선)
            ForEach(0..<dayCount, id: \.self) { i in
                LineMark(
                    x: .value("Day", i + 1),
                    y: .value("Q15", q15[i]),
                    series: .value("S", "Q15")
                )
                .foregroundStyle(Color.riskRedSoft)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .interpolationMethod(.monotone)
            }

            // 0% baseline
            RuleMark(y: .value("Baseline", 0.0))
                .foregroundStyle(Color.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.5))

            // 선택된 날짜 강조
            if let day = selectedDay, day >= 1, day <= dayCount {
                RuleMark(x: .value("Selected", day))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Day", day),
                    y: .value("Q05", q05[day - 1])
                )
                .foregroundStyle(Color.riskRed)
                .symbolSize(80)

                PointMark(
                    x: .value("Day", day),
                    y: .value("Q15", q15[day - 1])
                )
                .foregroundStyle(Color.riskRedSoft)
                .symbolSize(50)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f%%", v * 100)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v == 0 ? "오늘" : "+\(v)일").font(.caption2)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDays)
        .chartXScale(domain: 0.5...(Double(dayCount) + 0.5))
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = lastZoomScale * value
                    zoomScale = max(1.0, min(4.0, newScale))
                }
                .onEnded { _ in
                    lastZoomScale = zoomScale
                }
        )
        .overlay(alignment: .topLeading) {
            if let day = selectedDay, day >= 1, day <= dayCount {
                tooltip(day: day)
                    .padding(.top, 6)
                    .padding(.leading, 10)
                    .transition(.opacity)
            }
        }
        .frame(height: 220)
    }

    private var hint: some View {
        HStack(spacing: 14) {
            Label("핀치로 확대", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Label("탭하면 값", systemImage: "hand.point.up.left")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if zoomScale > 1.01 {
                Button("초기화") {
                    withAnimation { zoomScale = 1.0; lastZoomScale = 1.0 }
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
            Spacer()
        }
    }

    private func tooltip(day: Int) -> some View {
        let q05Val = q05[day - 1]
        let q15Val = q15[day - 1]
        return HStack(spacing: 8) {
            Text("+\(day)일").font(.caption2.weight(.bold))
            HStack(spacing: 3) {
                Circle().fill(.red).frame(width: 5, height: 5)
                Text(String(format: "%.2f%%", q05Val * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.riskRed)
            }
            HStack(spacing: 3) {
                Circle().fill(.red.opacity(0.65)).frame(width: 5, height: 5)
                Text(String(format: "%.2f%%", q15Val * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.riskRedSoft)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Ticker Row — 워치리스트 / 검색 결과 공통

struct TickerRow: View {
    let symbol: String
    let nameKr: String?
    let price: String?
    let priceChangePct: Double?     // e.g. 0.032
    let grade: String?              // optional badge
    let worstCasePct: Double?       // optional right-side big red text

    var body: some View {
        HStack(spacing: 12) {
            // Symbol bubble
            Text(symbol)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(GradeStyle.color(grade ?? "").opacity(0.15))
                .foregroundStyle(GradeStyle.color(grade ?? ""))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 56, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(nameKr ?? symbol).font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    if let p = price { Text(p).font(.caption).foregroundStyle(.secondary) }
                    if let c = priceChangePct {
                        Text(String(format: "%+.1f%%", c * 100))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(c >= 0 ? Color.riskRed : Color.trendUp)
                    }
                }
            }
            Spacer()
            if let w = worstCasePct {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("변동성 추정").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", w * 100))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.riskRed)
                }
            } else if let g = grade {
                RiskBadge(grade: g, compact: true)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Section header (마이페이지 등에서 재사용)

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if let t = trailing {
                Text(t).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}
