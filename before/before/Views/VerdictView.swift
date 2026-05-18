//
//  VerdictView.swift
//  before
//
//  결과 화면 — RiskAPI.verdict + path + attention 실제 호출.
//

import SwiftUI

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
                .disabled(favoriteToggling || !state.isAuthenticated)
            }
        }
        .sheet(isPresented: $showXAI) {
            XAISheet(
                narrative: verdict?.summaryNarrative,
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

        // "왜 이런 결과?" button
        Button {
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

            // 보조 데이터들은 병렬, 실패해도 메인 화면 유지
            async let attentionData = try? await RiskAPI.attention(ticker: ticker)
            async let pathDataResult = try? await RiskAPI.path(ticker: ticker)
            async let historyData = try? await PricesAPI.history(ticker: ticker, days: 30)

            self.attention = await attentionData
            self.pathData = await pathDataResult
            self.pastPrices = (await historyData)?.items ?? []
        } catch {
            self.errorMessage = error.localizedDescription
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
        guard state.isAuthenticated, !favoriteToggling else { return }
        favoriteToggling = true
        let prev = isFavorite
        isFavorite.toggle()    // optimistic
        do {
            if prev {
                _ = try await WatchlistAPI.remove(ticker: ticker)
            } else {
                _ = try await WatchlistAPI.add(ticker: ticker)
            }
        } catch {
            isFavorite = prev    // 롤백
        }
        favoriteToggling = false
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

struct XAISheet: View {
    let narrative: String?
    let features: [RiskXaiFeature]?
    let actionGuide: String?
    let backtest: RiskXaiBacktest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard

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
            .navigationTitle("왜 위험한가요?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: 요약 카드
    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("요약")
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
