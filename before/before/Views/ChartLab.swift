//
//  ChartLab.swift
//  before
//
//  두 가지 차트 컴포넌트 비교 페이지:
//   1) ChartLabAppleView   — Apple Swift Charts 프레임워크 (iOS 17+ 기본)
//   2) ChartLabCustomView  — SwiftUI Canvas + 직접 핀치/팬 제스처
//
//  공통: 9개 분위수 (Q05 ~ Q95) 칩 선택, 색상별 라인, 핀치 줌, 탭으로 값 확인.
//
//  진짜 데이터: Q05 / Q15 (백엔드 추론값).
//  데모 합성:   Q25, Q40, Q50, Q60, Q75, Q85, Q95
//             → 정규분포 가정 (Q05·Q15 로 mu·sigma 역산 후 다른 z 점수 적용).
//             → 백엔드 quantile_paths 확장 시 그대로 교체 가능.
//

import SwiftUI
import Charts

// MARK: - Quantile Model

enum QuantileKey: String, CaseIterable, Identifiable {
    case q05, q15, q25, q40, q50, q60, q75, q85, q95
    var id: String { rawValue }

    var label: String {
        switch self {
        case .q05: return "Q05"
        case .q15: return "Q15"
        case .q25: return "Q25"
        case .q40: return "Q40"
        case .q50: return "Q50"
        case .q60: return "Q60"
        case .q75: return "Q75"
        case .q85: return "Q85"
        case .q95: return "Q95"
        }
    }

    var subtitle: String {
        switch self {
        case .q05: return "최악 5%"
        case .q15: return "하방 15%"
        case .q25: return "약하방 25%"
        case .q40: return "보통하 40%"
        case .q50: return "중앙값"
        case .q60: return "보통상 60%"
        case .q75: return "약상방 75%"
        case .q85: return "상방 85%"
        case .q95: return "최상 95%"
        }
    }

    var color: Color {
        switch self {
        case .q05: return Color(red: 0.83, green: 0.10, blue: 0.10)   // 짙은 빨강
        case .q15: return Color(red: 0.92, green: 0.36, blue: 0.20)   // 주황빨강
        case .q25: return Color(red: 0.96, green: 0.60, blue: 0.20)   // 주황
        case .q40: return Color(red: 0.85, green: 0.75, blue: 0.30)   // 황토
        case .q50: return Color(red: 0.45, green: 0.45, blue: 0.45)   // 회색 (중앙)
        case .q60: return Color(red: 0.30, green: 0.78, blue: 0.55)   // 청록
        case .q75: return Color(red: 0.20, green: 0.68, blue: 0.85)   // 시안
        case .q85: return Color(red: 0.20, green: 0.45, blue: 0.92)   // 파랑
        case .q95: return Color(red: 0.40, green: 0.30, blue: 0.85)   // 보라
        }
    }

    /// 표준정규분포 z 점수 (역분위수)
    var zScore: Double {
        switch self {
        case .q05: return -1.645
        case .q15: return -1.036
        case .q25: return -0.674
        case .q40: return -0.253
        case .q50: return 0.0
        case .q60: return 0.253
        case .q75: return 0.674
        case .q85: return 1.036
        case .q95: return 1.645
        }
    }
}

struct QuantileBundle {
    let dayCount: Int
    let paths: [QuantileKey: [Double]]
    let isFullyReal: Bool   // 모든 분위수가 실 데이터인지

    /// 백엔드 `quantile_paths` dict 에서 우리가 쓰는 9개 키를 추출.
    /// 누락 분위수는 paths 에 빠진 채로 둠 (UI 가 알아서 처리).
    static func fromBackend(_ dict: [String: [Double]]) -> QuantileBundle? {
        // 백엔드 키 포맷: "0.05", "0.10", ..., "0.95"
        // QuantileKey 매핑
        let keyMap: [QuantileKey: String] = [
            .q05: "0.05", .q15: "0.15", .q25: "0.25",
            .q40: "0.40", .q50: "0.50", .q60: "0.60",
            .q75: "0.75", .q85: "0.85", .q95: "0.95",
        ]
        var paths: [QuantileKey: [Double]] = [:]
        for (key, backendKey) in keyMap {
            if let arr = dict[backendKey] {
                paths[key] = arr
            }
        }
        guard let anyPath = paths.values.first else { return nil }
        let allReal = paths.count == keyMap.count
        return QuantileBundle(dayCount: anyPath.count, paths: paths, isFullyReal: allReal)
    }

    /// q05/q15 만 백엔드 값, 나머지 분위수는 정규분포 가정으로 합성 (백엔드 quantile_paths 누락 시 폴백).
    static func synthesize(realQ05: [Double], realQ15: [Double]) -> QuantileBundle {
        let count = min(realQ05.count, realQ15.count)
        var paths: [QuantileKey: [Double]] = [.q05: realQ05, .q15: realQ15]
        var stats: [(mu: Double, sigma: Double)] = []
        for i in 0..<count {
            let sigma = max((realQ15[i] - realQ05[i]) / 0.609, 0.001)
            let mu = realQ15[i] + 1.036 * sigma
            stats.append((mu, sigma))
        }
        for key in [QuantileKey.q25, .q40, .q50, .q60, .q75, .q85, .q95] {
            paths[key] = stats.map { $0.mu + key.zScore * $0.sigma }
        }
        return QuantileBundle(dayCount: count, paths: paths, isFullyReal: false)
    }
}

// MARK: - Shared chips & layout

struct QuantileChip: View {
    let key: QuantileKey
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(key.color).frame(width: 8, height: 8)
                Text(key.label).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? key.color.opacity(0.18) : Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn ? key.color : Color.secondary.opacity(0.3),
                            lineWidth: isOn ? 1.5 : 0.5)
            )
            .foregroundStyle(isOn ? Color(.label) : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var hasContent = false

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, hasContent {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            hasContent = true
        }
        return CGSize(width: width, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { (i >= 0 && i < count) ? self[i] : nil }
}

// MARK: - Page A: Apple Swift Charts

struct ChartLabAppleView: View {
    let ticker: String

    @State private var bundle: QuantileBundle?
    @State private var visibleKeys: Set<QuantileKey> = [.q05, .q15, .q50, .q85, .q95]
    @State private var loading = true
    @State private var errorMessage: String?

    @State private var selectedDay: Int?
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 80)
                } else if let b = bundle {
                    header(b)
                    quantileChips
                    chartCard(b)
                    if let day = selectedDay {
                        valuesGrid(b, day: day)
                    }
                    legendCard
                    syntheticNote(b)
                } else if let msg = errorMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                        .padding(.vertical, 40)
                }
            }
            .padding(16)
        }
        .navigationTitle("\(ticker) · Apple Charts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ b: QuantileBundle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Swift Charts 프레임워크").font(.headline)
            Text("Apple 기본 — \(b.dayCount)일 9개 분위수")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quantileChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("분위수 선택").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("전체") { visibleKeys = Set(QuantileKey.allCases) }
                    .font(.caption2)
                Button("지우기") { visibleKeys = [] }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(QuantileKey.allCases) { key in
                        QuantileChip(key: key, isOn: visibleKeys.contains(key)) {
                            toggle(key)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func chartCard(_ b: QuantileBundle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chart(b)
            hint
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chart(_ b: QuantileBundle) -> some View {
        let sortedKeys = visibleKeys.sorted(by: { $0.zScore < $1.zScore })

        return Chart {
            ForEach(sortedKeys, id: \.self) { key in
                if let path = b.paths[key] {
                    ForEach(0..<path.count, id: \.self) { i in
                        LineMark(
                            x: .value("Day", i + 1),
                            y: .value("Pct", path[i]),
                            series: .value("S", key.rawValue)
                        )
                        .foregroundStyle(key.color)
                        .lineStyle(StrokeStyle(
                            lineWidth: key == .q50 ? 2.2 : 1.7,
                            lineCap: .round,
                            dash: key == .q50 ? [4, 3] : []
                        ))
                        .interpolationMethod(.monotone)
                    }
                }
            }

            RuleMark(y: .value("Baseline", 0.0))
                .foregroundStyle(Color.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 0.5))

            if let day = selectedDay, day >= 1, day <= b.dayCount {
                RuleMark(x: .value("Selected", day))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                ForEach(sortedKeys, id: \.self) { key in
                    if let v = b.paths[key]?[safe: day - 1] {
                        PointMark(x: .value("Day", day), y: .value("V", v))
                            .foregroundStyle(key.color)
                            .symbolSize(60)
                    }
                }
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
            AxisMarks(values: .stride(by: 5)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v == 0 ? "오늘" : "+\(v)일").font(.caption2)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDays(total: b.dayCount))
        .chartXScale(domain: 0.5...(Double(b.dayCount) + 0.5))
        .gesture(
            MagnificationGesture()
                .onChanged { v in zoom = max(1.0, min(6.0, lastZoom * v)) }
                .onEnded { _ in lastZoom = zoom }
        )
        .frame(height: 280)
    }

    private func valuesGrid(_ b: QuantileBundle, day: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("+\(day)일 값").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 6) {
                ForEach(QuantileKey.allCases) { key in
                    if visibleKeys.contains(key), let v = b.paths[key]?[safe: day - 1] {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(key.color).frame(width: 6, height: 6)
                                Text(key.label).font(.caption2.weight(.bold))
                            }
                            Text(String(format: "%+.2f%%", v * 100))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(key.color)
                        }
                        .padding(6).frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("색상 범례").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(QuantileKey.allCases) { key in
                    HStack(spacing: 4) {
                        Rectangle().fill(key.color).frame(width: 14, height: 2)
                        Text("\(key.label) · \(key.subtitle)")
                            .font(.caption2)
                            .foregroundStyle(visibleKeys.contains(key) ? Color(.label) : .purple)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func syntheticNote(_ b: QuantileBundle) -> some View {
        Group {
            if b.isFullyReal {
                Label("9개 분위수 모두 백엔드 m3 모델 실 추론값", systemImage: "checkmark.seal.fill")
                    .font(.caption2).foregroundStyle(.green)
            } else {
                Text("Q05·Q15 만 실 추론값. 나머지 분위수는 정규분포 가정으로 보간 (백엔드 quantile_paths 응답 누락 시 폴백).")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var hint: some View {
        HStack(spacing: 12) {
            Label("핀치 줌", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                .font(.caption2).foregroundStyle(.tertiary)
            Label("탭 = 값", systemImage: "hand.point.up.left")
                .font(.caption2).foregroundStyle(.tertiary)
            if zoom > 1.01 {
                Button("초기화") {
                    withAnimation { zoom = 1; lastZoom = 1 }
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
            Spacer()
        }
    }

    private func visibleDays(total: Int) -> Double { max(Double(total) / Double(zoom), 4) }

    private func toggle(_ key: QuantileKey) {
        if visibleKeys.contains(key) { visibleKeys.remove(key) }
        else { visibleKeys.insert(key) }
    }

    private func load() async {
        loading = true
        do {
            async let verdict = RiskAPI.verdict(ticker: ticker)
            async let path = try? await RiskAPI.path(ticker: ticker)
            let v = try await verdict
            let p = await path
            // 백엔드 quantile_paths 가 있으면 진짜 19개 분위수 사용 — 없으면 q05/q15 로 합성.
            if let qp = p?.quantilePaths, let b = QuantileBundle.fromBackend(qp) {
                self.bundle = b
            } else {
                self.bundle = QuantileBundle.synthesize(
                    realQ05: v.prediction.q05Path,
                    realQ15: v.prediction.q15Path
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Page B: Canvas + manual zoom/pan

struct ChartLabCustomView: View {
    let ticker: String

    @State private var bundle: QuantileBundle?
    @State private var visibleKeys: Set<QuantileKey> = [.q05, .q15, .q50, .q85, .q95]
    @State private var loading = true
    @State private var errorMessage: String?

    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var panX: CGFloat = 0
    @State private var lastPanX: CGFloat = 0
    @State private var selectedDay: Int?

    private let chartHeight: CGFloat = 320
    private let leftPad: CGFloat = 44
    private let topPad: CGFloat = 12
    private let bottomPad: CGFloat = 26

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 80)
                } else if let b = bundle {
                    header
                    quantileChips
                    chartCard(b)
                    if let day = selectedDay {
                        valuesGrid(b, day: day)
                    }
                    syntheticNote(b)
                } else if let msg = errorMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(16)
        }
        .navigationTitle("\(ticker) · Canvas 차트")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Canvas 직접 렌더").font(.headline)
            Text("핀치 8배 확대 + 드래그 패닝 — 벡터 항상 선명")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quantileChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("분위수 선택").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("전체") { visibleKeys = Set(QuantileKey.allCases) }
                    .font(.caption2)
                Button("지우기") { visibleKeys = [] }
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(QuantileKey.allCases) { key in
                        QuantileChip(key: key, isOn: visibleKeys.contains(key)) {
                            if visibleKeys.contains(key) { visibleKeys.remove(key) }
                            else { visibleKeys.insert(key) }
                        }
                    }
                }
            }
        }
    }

    private func chartCard(_ b: QuantileBundle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                canvas(b, size: geo.size)
                    .clipped()
            }
            .frame(height: chartHeight)
            hint
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func canvas(_ b: QuantileBundle, size: CGSize) -> some View {
        let dayCount = b.dayCount
        let baseSpan = size.width - leftPad
        let totalSpan = baseSpan * zoom
        let dayWidth = totalSpan / CGFloat(max(dayCount - 1, 1))

        let visibleValues = visibleKeys.flatMap { b.paths[$0] ?? [] }
        let minV = (visibleValues.min() ?? -0.25) * 1.1
        let maxV = (visibleValues.max() ?? 0.1) * 1.1
        let yRange = max(maxV - minV, 0.01)
        let drawHeight = size.height - topPad - bottomPad

        func xFor(_ day: Int) -> CGFloat {
            leftPad + panX + CGFloat(day - 1) * dayWidth
        }
        func yFor(_ value: Double) -> CGFloat {
            let pct = (value - minV) / yRange
            return topPad + drawHeight * (1 - CGFloat(pct))
        }
        func dayFromX(_ x: CGFloat) -> Int? {
            let f = (x - leftPad - panX) / dayWidth + 1
            let d = Int(round(f))
            return (d >= 1 && d <= dayCount) ? d : nil
        }

        return Canvas { ctx, sz in
            // y축 grid + 라벨
            for tick in evenTicks(min: minV, max: maxV, count: 4) {
                let y = yFor(tick)
                var line = Path()
                line.move(to: CGPoint(x: leftPad, y: y))
                line.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(line, with: .color(Color.secondary.opacity(0.13)), lineWidth: 0.5)
                let txt = Text(String(format: "%+.0f%%", tick * 100))
                    .font(.caption2).foregroundColor(.secondary)
                ctx.draw(txt, at: CGPoint(x: leftPad - 4, y: y), anchor: .trailing)
            }

            // 0% baseline
            if minV < 0, maxV > 0 {
                let y0 = yFor(0)
                var base = Path()
                base.move(to: CGPoint(x: leftPad, y: y0))
                base.addLine(to: CGPoint(x: sz.width, y: y0))
                ctx.stroke(base, with: .color(Color.secondary.opacity(0.45)), lineWidth: 0.7)
            }

            // x축 라벨
            for day in stride(from: 0, through: dayCount, by: 5) {
                let x = xFor(day == 0 ? 1 : day)
                if x < leftPad - 20 || x > sz.width + 20 { continue }
                let label = day == 0 ? "오늘" : "+\(day)일"
                let txt = Text(label).font(.caption2).foregroundColor(.secondary)
                ctx.draw(txt, at: CGPoint(x: x, y: sz.height - 12), anchor: .center)
            }

            // 분위수 라인
            let sortedKeys = visibleKeys.sorted(by: { $0.zScore < $1.zScore })
            for key in sortedKeys {
                guard let path = b.paths[key] else { continue }
                var p = Path()
                for (i, v) in path.enumerated() {
                    let pt = CGPoint(x: xFor(i + 1), y: yFor(v))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                let lw: CGFloat = key == .q50 ? 2.4 : 1.8
                ctx.stroke(p, with: .color(key.color),
                           style: StrokeStyle(lineWidth: lw,
                                              lineCap: .round, lineJoin: .round,
                                              dash: key == .q50 ? [4, 3] : []))
            }

            // 십자선 + 포인트
            if let day = selectedDay {
                let x = xFor(day)
                if x >= leftPad - 5, x <= sz.width + 5 {
                    var vline = Path()
                    vline.move(to: CGPoint(x: x, y: topPad))
                    vline.addLine(to: CGPoint(x: x, y: sz.height - bottomPad))
                    ctx.stroke(vline, with: .color(Color.gray.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    for key in sortedKeys {
                        if let v = b.paths[key]?[safe: day - 1] {
                            let pt = CGPoint(x: x, y: yFor(v))
                            let r: CGFloat = key == .q50 ? 5 : 4
                            let circle = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                                width: r * 2, height: r * 2))
                            ctx.fill(circle, with: .color(key.color))
                        }
                    }
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { v in
                    let s = lastZoom * v
                    zoom = max(1.0, min(8.0, s))
                }
                .onEnded { _ in lastZoom = zoom }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if zoom > 1.05 {
                        let new = lastPanX + value.translation.width
                        let maxOff = (baseSpan * zoom) - baseSpan
                        panX = max(-maxOff, min(0, new))
                    } else {
                        if let d = dayFromX(value.location.x) {
                            selectedDay = d
                        }
                    }
                }
                .onEnded { _ in lastPanX = panX }
        )
    }

    private func valuesGrid(_ b: QuantileBundle, day: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("+\(day)일 값").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 6) {
                ForEach(QuantileKey.allCases) { key in
                    if visibleKeys.contains(key), let v = b.paths[key]?[safe: day - 1] {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(key.color).frame(width: 6, height: 6)
                                Text(key.label).font(.caption2.weight(.bold))
                            }
                            Text(String(format: "%+.2f%%", v * 100))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(key.color)
                        }
                        .padding(6).frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func syntheticNote(_ b: QuantileBundle) -> some View {
        Group {
            if b.isFullyReal {
                Label("9개 분위수 모두 백엔드 m3 모델 실 추론값", systemImage: "checkmark.seal.fill")
                    .font(.caption2).foregroundStyle(.green)
            } else {
                Text("Q05·Q15 만 실 추론값. 나머지는 정규분포 가정으로 보간 (폴백).")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var hint: some View {
        HStack(spacing: 12) {
            Label("핀치 8배", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                .font(.caption2).foregroundStyle(.tertiary)
            if zoom > 1.05 {
                Label("드래그로 이동", systemImage: "hand.draw")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Label("탭 = 값", systemImage: "hand.point.up.left")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            if zoom > 1.01 || panX != 0 {
                Button("초기화") {
                    withAnimation { zoom = 1; lastZoom = 1; panX = 0; lastPanX = 0 }
                }
                .font(.caption2).buttonStyle(.borderless)
            }
            Spacer()
        }
    }

    private func evenTicks(min: Double, max: Double, count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let step = (max - min) / Double(count)
        return (0...count).map { min + Double($0) * step }
    }

    private func load() async {
        loading = true
        do {
            async let verdict = RiskAPI.verdict(ticker: ticker)
            async let path = try? await RiskAPI.path(ticker: ticker)
            let v = try await verdict
            let p = await path
            // 백엔드 quantile_paths 가 있으면 진짜 19개 분위수 사용 — 없으면 q05/q15 로 합성.
            if let qp = p?.quantilePaths, let b = QuantileBundle.fromBackend(qp) {
                self.bundle = b
            } else {
                self.bundle = QuantileBundle.synthesize(
                    realQ05: v.prediction.q05Path,
                    realQ15: v.prediction.q15Path
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        loading = false
    }
}

#Preview("Apple") {
    NavigationStack { ChartLabAppleView(ticker: "NVDA") }
}

#Preview("Custom") {
    NavigationStack { ChartLabCustomView(ticker: "NVDA") }
}
