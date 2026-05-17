//
//  HomeView.swift
//  before
//
//  탭 1 — 홈. spotlight 카드(가장 위험한 종목) + 워치리스트.
//  spotlight 는 RiskAPI.spotlight() 호출, watchlist 는 일단 mock (인증 단계 후 교체).
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var spotlight: SpotlightItem?
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var watchlist: [WatchlistItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Brand
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("before").font(.title.weight(.bold))
                        Text(".").font(.title.weight(.bold)).foregroundStyle(.blue)
                        Spacer()
                        ProfileBubble(initial: state.isAuthenticated ? state.userInitial : nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // Search bar
                    NavigationLink {
                        SearchView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            Text("티커 또는 종목명 검색").foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)

                    // Spotlight section header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TODAY")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("오늘 가장 변동성이 큰 종목")
                            .font(.title3.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Spotlight card — loading / data / error
                    spotlightSection
                        .padding(.horizontal, 20)

                    // Watchlist (mock — 인증 단계 후 교체)
                    HStack {
                        Text("관심 종목").font(.title3.weight(.bold))
                        Spacer()
                        Text("변동성 높은 순").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    watchlistSection
                        .padding(.horizontal, 20)

                    // Disclaimer
                    Text("본 서비스는 투자자문업 등록 사업자가 아니며, 통계 모델에 기반한 정보 제공만을 목적으로 합니다. 특정 종목의 매수·매도를 권유하지 않으며, 과거 통계는 미래 결과를 보장하지 않습니다. 투자 판단과 그 결과에 따른 손실은 투자자 본인에게 귀속됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .refreshable {
                await loadSpotlight()
                await loadWatchlist()
            }
            .task {
                await loadSpotlight()
                await loadWatchlist()
            }
        }
    }

    // MARK: - Watchlist

    @ViewBuilder
    private var watchlistSection: some View {
        if !state.isAuthenticated {
            VStack(spacing: 8) {
                Image(systemName: "heart").foregroundStyle(.secondary)
                Text("로그인하면 관심 종목을 등록할 수 있어요")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("로그인 / 회원가입") { state.route = .auth }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if watchlist.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle").foregroundStyle(.secondary)
                Text("아직 관심 종목이 없어요")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("검색 화면에서 종목 추가")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 0) {
                ForEach(watchlist) { t in
                    NavigationLink {
                        VerdictView(ticker: t.ticker)
                    } label: {
                        TickerRow(
                            symbol: t.ticker,
                            nameKr: t.companyNameKr,
                            price: nil,
                            priceChangePct: nil,
                            grade: nil,
                            worstCasePct: nil
                        )
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await removeFromWatchlist(ticker: t.ticker) }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    if t.id != watchlist.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func loadWatchlist() async {
        guard state.isAuthenticated else {
            self.watchlist = []
            return
        }
        do {
            let data = try await WatchlistAPI.list()
            self.watchlist = data.items
        } catch {
            // 조용히 실패 — 헤더 카드 영향 X
            self.watchlist = []
        }
    }

    private func removeFromWatchlist(ticker: String) async {
        // Optimistic UI — 먼저 로컬 제거
        let backup = watchlist
        watchlist.removeAll { $0.ticker == ticker }
        do {
            _ = try await WatchlistAPI.remove(ticker: ticker)
        } catch {
            // 실패하면 롤백
            self.watchlist = backup
        }
    }

    // MARK: - Spotlight section

    @ViewBuilder
    private var spotlightSection: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.red.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if let s = spotlight {
            NavigationLink {
                VerdictView(ticker: s.ticker)
            } label: {
                spotlightCard(s)
            }
            .buttonStyle(.plain)
        } else if let msg = errorMessage {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("다시 시도") { Task { await loadSpotlight() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                Text("오늘은 고위험 종목이 관측되지 않았습니다.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func spotlightCard(_ s: SpotlightItem) -> some View {
        let pct = s.worstCaseDouble
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(s.ticker)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(GradeStyle.color(s.grade).opacity(0.15))
                    .foregroundStyle(GradeStyle.color(s.grade))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.companyNameKr ?? s.ticker).font(.body.weight(.semibold))
                    Text(s.priceDoubleString).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                RiskBadge(grade: s.grade)
            }

            VStack(alignment: .center, spacing: 4) {
                Text("과거 데이터 기반 30일 변동성 추정")
                    .font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", pct * 100))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text("과거 유사 변동성 구간의 통계적 추정치이며, 미래 가격을 예측하지 않습니다.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            HStack(spacing: 6) {
                Image(systemName: "clock").foregroundStyle(.secondary).font(.caption2)
                Text("\(s.asOf) 기준 통계적 관측치입니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Load

    private func loadSpotlight() async {
        loading = true
        errorMessage = nil
        do {
            let data = try await RiskAPI.spotlight()
            self.spotlight = data.spotlight
        } catch {
            self.errorMessage = error.localizedDescription
        }
        loading = false
    }
}

private struct ProfileBubble: View {
    let initial: String?    // nil 이면 게스트 아이콘

    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay(
                Group {
                    if let s = initial {
                        Text(s).font(.caption.weight(.bold)).foregroundStyle(.blue)
                    } else {
                        Image(systemName: "person").font(.caption).foregroundStyle(.blue)
                    }
                }
            )
    }
}

#Preview { HomeView() }
