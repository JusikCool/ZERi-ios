//
//  VerdictView.swift
//  before
//
//  결과 화면 — RiskAPI.verdict + path + attention 실제 호출.
//

import SwiftUI
import UIKit

struct VerdictView: View {
    let ticker: String

    @EnvironmentObject var state: AppState
    @State private var verdict: RiskVerdictData?
    @State private var pathData: RiskPathData?
    @State private var attention: RiskAttentionData?
    @State private var pastPrices: [HistoricalPriceItem] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showXAI = false
    @State private var isFavorite = false
    @State private var favoriteToggling = false
    @State private var showLoginPrompt = false   // 비로그인 사용자가 좋아요 탭 시 alert

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if loading {
                    HStack {
                        Spacer(); ProgressView(); Spacer()
                    }
                    .padding(.vertical, 60)
                } else if let v = verdict {
                    content(v)
                } else if let msg = errorMessage {
                    errorBlock(msg)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .red : Color(.label))
                }
                // 비로그인이어도 탭은 가능 — toggleFavorite 안에서 alert 분기.
                .disabled(favoriteToggling)
            }
        }
        .alert("로그인이 필요해요", isPresented: $showLoginPrompt) {
            Button("취소", role: .cancel) {}
            Button("로그인하기") {
                Haptics.light()
                state.route = .auth
            }
        } message: {
            Text("관심 종목 등록은 로그인 후에 이용할 수 있어요.")
        }
        .sheet(isPresented: $showXAI) {
            // 메인 화면 AINarrativeCard 가 이미 narrative 를 노출하므로 시트에서는 제거.
            // 시트는 "더 깊은 근거" 역할 — 백테스트 + 액션가이드 + top features.
            XAISheet(
                narrative: nil,
                features: attention?.features ?? verdict?.xai?.features,
                actionGuide: attention?.actionGuide ?? verdict?.xai?.actionGuide,
                backtest: attention?.backtest ?? verdict?.xai?.backtest
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func content(_ v: RiskVerdictData) -> some View {
        let worst = v.worstCaseDouble

        // Header
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(v.ticker)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text("\(v.asOf) 기준")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(v.companyNameKr ?? v.ticker)
                .font(.largeTitle.weight(.bold))
            HStack(spacing: 8) {
                Text(v.priceDisplay).font(.title3.weight(.semibold))
            }
        }

        // Worst case big card
        WorstCaseCard(
            grade: v.grade.value,
            worstCasePct: worst,
            subtitle: "30일 통계 모델 결과"
        )

        // Main chart — 과거 종가 + 미래 Q05/Q15 fan
        let q05 = pathData?.q05Path ?? v.prediction.q05Path
        let q15 = pathData?.q15Path ?? v.prediction.q15Path
        let currentPrice = Double(v.currentPrice ?? "0") ?? 0

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("가격 흐름").font(.subheadline.weight(.semibold))
                Spacer()
                Text("과거 \(pastPrices.count)일 + 미래 \(min(q05.count, q15.count))일")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            RiskMainChart(
                pastPrices: pastPrices,
                q05: q05,
                q15: q15,
                currentPrice: currentPrice,
                worstCasePct: worst
            )

            Text("회색은 실제 과거 종가, 빨강은 통계 모델 예측. 미래 결과를 보장하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        // 30-day daily breakdown (펼치기/접기)
        DailyBreakdownCard(q05: q05, q15: q15, baseDate: v.prediction.baseDate)

        // AI 해설 카드 — 차트로 시각 이해 후 자연어 해설 순서.
        // detailedNarrative 없으면 summaryNarrative 로 폴백, 둘 다 없으면 카드 자체 숨김.
        if let narrative = v.detailedNarrative ?? v.summaryNarrative, !narrative.isEmpty {
            AINarrativeCard(
                narrative: narrative,
                isPolished: v.detailedNarrative != nil,
                baseDate: v.detailedNarrativeBaseDate,
                asOf: v.asOf
            )
        }

        // "왜 이런 결과?" button
        Button {
            Haptics.light()
            showXAI = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("왜 이런 결과가 나왔나요?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Text("핵심 변수 3개 · 과거 유사 패턴")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)

        // Disclaimer
        Text("본 서비스는 투자자문업 등록 사업자가 아니며, 통계 모델에 기반한 정보 제공만을 목적으로 합니다. 특정 종목의 매수·매도를 권유하지 않으며, 과거 통계는 미래 결과를 보장하지 않습니다. 투자 판단과 그 결과에 따른 손실은 투자자 본인에게 귀속됩니다.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 8)

        Text("\(v.prediction.modelName) \(v.prediction.modelVersion)")
            .font(.caption2.monospaced())
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
            .padding(.bottom, 24)
    }

    private func errorBlock(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("데이터를 불러오지 못했어요")
                .font(.headline)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await load() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            // 메인 verdict 는 필수 (실패 시 화면 못 띄움)
            self.verdict = try await RiskAPI.verdict(ticker: ticker)

            // 최근 조회 종목 기록 — 검색 탭 "최근 조회"에 자동 반영.
            // 실패해도 화면 동작에는 영향 없으므로 fire-and-forget.
            RecentTickersStore.add(
                ticker: ticker,
                companyNameKr: self.verdict?.companyNameKr
            )

            // 보조 데이터들은 병렬, 실패해도 메인 화면 유지
            async let attentionData = try? await RiskAPI.attention(ticker: ticker)
            async let pathDataResult = try? await RiskAPI.path(ticker: ticker)
            async let historyData = try? await PricesAPI.history(ticker: ticker, days: 30)

            self.attention = await attentionData
            self.pathData = await pathDataResult
            self.pastPrices = (await historyData)?.items ?? []
        } catch where error.isCancellation {
            // 탭 전환/view rebuild 로 인한 취소 → 무시
        } catch {
            self.errorMessage = error.localizedDescription
            Haptics.notify(.error)    // 로드 실패 → 에러 햅틱
        }
        loading = false

        // 워치리스트 상태도 같이 갱신
        if state.isAuthenticated {
            if let list = try? await WatchlistAPI.list() {
                self.isFavorite = list.items.contains { $0.ticker == ticker }
            }
        }
    }

    private func toggleFavorite() async {
        guard !favoriteToggling else { return }
        // 비로그인 → 시스템 alert 띄워 로그인 유도. 햅틱 warning 으로 "막힘" 신호.
        guard state.isAuthenticated else {
            Haptics.notify(.warning)
            showLoginPrompt = true
            return
        }
        favoriteToggling = true
        let prev = isFavorite
        isFavorite.toggle()    // optimistic
        Haptics.impact(.medium)    // 사용자가 즉시 인지하도록 optimistic 시점에 발화
        do {
            if prev {
                _ = try await WatchlistAPI.remove(ticker: ticker)
            } else {
                _ = try await WatchlistAPI.add(ticker: ticker)
            }
        } catch {
            isFavorite = prev    // 롤백
            Haptics.notify(.error)    // 롤백 = 사용자의 의도와 어긋남 → 에러 햅틱
        }
        favoriteToggling = false
    }
}

// MARK: 에러 헬퍼 — Task / URLSession 취소는 사용자 의도와 무관하므로 alert 에서 제외.
// .task 가 view rebuild 시 자동 cancel 되는 정상 흐름까지 alert 로 띄우면 cancelled 가 폭증.
extension Error {
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError, url.code == .cancelled { return true }
        return false
    }
}

// MARK: 햅틱 헬퍼 — UIKit 의존성을 한곳에 모아 캡슐화.
// 사용 정책: 사용자 의도가 시스템에 반영된 시점에 한 번. 단순 스크롤/탐색엔 X.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }
    static func light() { impact(.light) }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var dashed: Bool = false
    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 2)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Daily Breakdown (30일 일별 펼침)

private struct DailyBreakdownCard: View {
    let q05: [Double]
    let q15: [Double]
    let baseDate: String   // "2026-05-15" iso
    @State private var expanded = false

    private var dayCount: Int { min(q05.count, q15.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dayCount)일 일별 상세")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("기준일 +1일 ~ +\(dayCount)일까지의 분위수 값")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider()
                // 헤더
                HStack {
                    Text("일").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("Q05 (최악)").font(.caption2.weight(.bold)).foregroundStyle(Color.riskRedSoft)
                        .frame(width: 90, alignment: .trailing)
                    Text("Q15 (보통)").font(.caption2.weight(.bold)).foregroundStyle(Color.riskRedSoft)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<dayCount, id: \.self) { i in
                            row(day: i + 1, q05Value: q05[i], q15Value: q15[i])
                            if i < dayCount - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 360)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(day: Int, q05Value: Double, q15Value: Double) -> some View {
        HStack {
            Text(dateLabel(day))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(String(format: "%+.2f%%", q05Value * 100))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.riskRed)
                .frame(width: 90, alignment: .trailing)
            Text(String(format: "%+.2f%%", q15Value * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.riskRedSoft)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func dateLabel(_ offset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let base = formatter.date(from: baseDate) else {
            return "+\(offset)일"
        }
        let target = Calendar.current.date(byAdding: .day, value: offset, to: base) ?? base
        let out = DateFormatter()
        out.dateFormat = "MM/dd"
        return out.string(from: target)
    }
}

// MARK: - XAI Sheet
//
// 본 시트는 뉴스/공시 등 텍스트 근거를 사후 결합하지 않는다.
// 모델 입력 (가격·거래량·변동성·기술적 지표·거시지표) 에 한정한 XAI 설명만 노출한다.
// TFT 변수 선택 + attention weight → rule-based JSON → LLM summary 의 결과를 그대로 렌더링한다.

// MARK: AI 해설 카드 — 차트 시각 이해 → 자연어 해설 순서로 배치.
// detailedNarrative(LLM 정제)가 있으면 "AI 해설" 라벨 + 보라 accent,
// 없으면 summaryNarrative(rule-based) 로 폴백 + 회색 톤.
struct AINarrativeCard: View {
    let narrative: String
    let isPolished: Bool       // true 면 Upstage Solar 정제본, false 면 template fallback
    let baseDate: String?      // detailedNarrative 기준일 (asOf 와 다르면 묵은 데이터)
    let asOf: String

    @Environment(\.colorScheme) private var colorScheme

    private var isStale: Bool {
        guard let base = baseDate else { return false }
        return base != asOf
    }

    // 보라 = AI 컨텐츠, 회색 = rule-based 폴백.
    // 다크 모드에서는 SwiftUI 기본 .purple 이 너무 형광 → 라이트/다크 톤 분리.
    // 라이트: 표준 purple (눈에 잘 띔)
    // 다크: systemIndigo 톤 (차분한 보라, 흰 텍스트와 대비도 유지)
    private var accent: Color {
        guard isPolished else { return Color(.systemGray2) }
        return colorScheme == .dark ? Color(.systemIndigo) : Color(.systemPurple)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 왼쪽 accent bar — "인용/특별 컨텐츠" 시각 신호. 글자 늘어나면 같이 늘어남.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 12) {
                // 헤더 라인 — 아이콘 + 라벨 + (묵은 데이터면) 기준일
                HStack(spacing: 6) {
                    Image(systemName: isPolished ? "sparkles" : "text.alignleft")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(isPolished ? "AI 해설" : "요약")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .textCase(.none)
                    if isStale, let base = baseDate {
                        Text("· \(base) 기준")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                // 본문 — 가독성 핵심. body 크기 + serif design + lineSpacing 으로 신문 사설 톤.
                // Dynamic Type 따라가도록 .system(.body, design:) 사용.
                Text(narrative)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color(.label))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)    // 길게 눌러 복사 (Apple 표준 행동)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // 살짝 그라데이션 — AI 컨텐츠를 다른 카드와 차별화.
            // 폴백 상태에서는 거의 평탄해 보이도록 회색 톤 + 약한 대비.
            // 다크에선 동일 opacity 가 너무 흐릿해 보여 살짝 더 강하게.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isPolished
                            ? [
                                Color(.secondarySystemBackground),
                                accent.opacity(colorScheme == .dark ? 0.12 : 0.06)
                              ]
                            : [Color(.secondarySystemBackground), Color(.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct XAISheet: View {
    let narrative: String?
    let features: [RiskXaiFeature]?
    let actionGuide: String?
    let backtest: RiskXaiBacktest?

    // 시트 안에 보여줄 게 하나라도 있나 — 셋 다 비면 요약 카드 자체를 숨김.
    private var hasSummaryContent: Bool {
        let n = (narrative?.isEmpty == false)
        let b = (backtest?.coveragePct != nil) || (backtest?.kupiecPass != nil)
        let g = (actionGuide?.isEmpty == false)
        return n || b || g
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if hasSummaryContent {
                        summaryCard
                    }

                    if let feats = features, !feats.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(feats.enumerated()), id: \.element.id) { idx, f in
                                FeatureCard(rank: idx + 1, feature: f)
                            }
                        }
                    } else {
                        Text("XAI 데이터가 아직 준비되지 않았습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    Text("본 데이터는 과거 통계적 관측치이며, 미래 결과를 보장하지 않습니다.")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("왜 위험한가요?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: 요약 카드 — narrative 는 메인 화면에서 노출되므로 시트에서는 backtest + actionGuide 중심.
    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 라벨 — narrative 있으면 "요약", 없으면 컨텐츠에 맞춰 "신뢰 평가".
            Text((narrative?.isEmpty == false) ? "요약" : "신뢰 평가")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            if let n = narrative, !n.isEmpty {
                Text(n).font(.body)
            }

            if let bt = backtest, bt.coveragePct != nil || bt.kupiecPass != nil {
                BacktestInset(backtest: bt)
            }

            if let guide = actionGuide, !guide.isEmpty {
                ActionGuideInset(text: guide)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: 요약 카드 내부 inset — 백테스트 신뢰 평가
private struct BacktestInset: View {
    let backtest: RiskXaiBacktest
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("백테스트 기반 신뢰 평가")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if let cov = backtest.coveragePct {
                    Text(String(format: "Coverage %.0f%%", cov * 100))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if backtest.coveragePct != nil && backtest.kupiecPass != nil {
                    Text("·").foregroundStyle(.tertiary)
                }
                if let pass = backtest.kupiecPass {
                    Text(pass ? "Kupiec pass" : "Kupiec fail")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pass ? Color(.label) : Color.riskRed)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: 요약 카드 내부 inset — 행동 가이드
private struct ActionGuideInset: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color(.label))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.riskRedSoft.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Feature Card (번호 + 이름 + % + bar + 보조지표 + 해석 + 확인사항)
private struct FeatureCard: View {
    let rank: Int
    let feature: RiskXaiFeature

    private var accent: Color {
        feature.weight >= 0.30 ? Color.riskRed : Color.riskRedSoft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 — 번호 + 라벨 + 퍼센트
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.riskRedSoft.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.riskRed)
                }
                Text(feature.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.0f%%", feature.weight * 100))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
            }

            ProgressView(value: min(max(feature.weight, 0), 1))
                .tint(accent)

            // 보조 지표 inset (auxLabel + auxValue)
            if let auxLabel = feature.auxLabel, let auxValue = feature.auxValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(auxLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(auxValue)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // 해석
            if let interp = feature.interpretation ?? feature.description, !interp.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("해석")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(interp)
                        .font(.footnote)
                        .foregroundStyle(Color(.label))
                }
            }

            // 확인하세요
            if let action = feature.actionHint, !action.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("확인하세요")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(action)
                        .font(.footnote)
                        .foregroundStyle(Color(.label))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack { VerdictView(ticker: "NVDA") }
}
