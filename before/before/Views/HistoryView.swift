//
//  HistoryView.swift
//  before
//
//  탭 3 — 분석 기록. HistoryAPI.list() 호출.
//  비로그인 시 안내 + 로그인 버튼.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var state: AppState
    @State private var items: [HistoryItem] = []
    @State private var filter: String? = nil
    @State private var loading = false
    @State private var errorMessage: String?

    private let filters: [(label: String, value: String?)] = [
        ("전체", nil),
        ("높음", "VOLATILITY_HIGH"),
        ("중간", "VOLATILITY_MID"),
        ("보통", "VOLATILITY_LOW"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !state.isAuthenticated {
                    guestPrompt
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("분석 기록")
            .navigationBarTitleDisplayMode(.large)
            .task(id: filter) {
                if state.isAuthenticated { await load() }
            }
            .refreshable {
                if state.isAuthenticated { await load() }
            }
        }
    }

    private var guestPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("로그인하면 분석 기록을 볼 수 있어요")
                .font(.headline)
            Text("verdict 화면에서 조회한 종목이\nT+30 평가와 함께 자동 저장됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                state.route = .auth
            } label: {
                Text("로그인 / 회원가입")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.label))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.label) { f in
                            Button {
                                filter = f.value
                            } label: {
                                Text(f.label)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(filter == f.value ? Color(.label) : Color(.secondarySystemBackground))
                                    .foregroundStyle(filter == f.value ? Color(.systemBackground) : Color(.label))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 40)
                } else if let msg = errorMessage {
                    errorBlock(msg)
                } else if items.isEmpty {
                    emptyBlock
                } else {
                    Text("최근 분석 · \(items.count)건")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink {
                                VerdictView(ticker: item.ticker)
                            } label: {
                                historyCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Text("본 서비스는 투자자문업 등록 사업자가 아니며, 통계 모델에 기반한 정보 제공만을 목적으로 합니다.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
    }

    private var emptyBlock: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
            Text("아직 분석 기록이 없습니다")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("종목 verdict 화면 진입 시 자동 저장됩니다.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorBlock(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("다시 시도") { Task { await load() } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func historyCard(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.ticker)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(GradeStyle.color(item.grade).opacity(0.15))
                            .foregroundStyle(GradeStyle.color(item.grade))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(item.companyNameKr ?? item.ticker).font(.body.weight(.semibold))
                    }
                    Text(item.queriedAt.prefix(16)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                RiskBadge(grade: item.grade, compact: true)
            }

            HStack(spacing: 24) {
                col("조회 시점가", "$\(item.priceAtQuery)", color: nil)
                col("추정 변동",
                    String(format: "%.1f%%", item.worstCasePct.asDouble * 100),
                    color: .red)
                col("30일 사후", outcomeText(item), color: outcomeColor(item.outcome))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func outcomeText(_ item: HistoryItem) -> String {
        guard let o = item.outcome else { return "평가 중" }
        let pct = (item.outcomePct ?? "0").asDouble * 100
        let label: String = {
            switch o {
            case "price_dropped": return "하락"
            case "price_rose":    return "상승"
            case "flat":          return "보합"
            default:               return o
            }
        }()
        return String(format: "%@ %+.1f%%", label, pct)
    }

    private func outcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "price_dropped": return Color.riskRed
        case "price_rose":    return Color.trendUp
        case "flat":          return .secondary
        default:               return .secondary
        }
    }

    private func col(_ label: String, _ value: String, color: Color?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color ?? Color(.label))
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let data = try await HistoryAPI.list(grade: filter)
            self.items = data.items
        } catch {
            self.errorMessage = error.localizedDescription
        }
        loading = false
    }
}

#Preview { HistoryView().environmentObject(AppState()) }
