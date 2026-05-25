//
//  SearchView.swift
//  before
//
//  탭 2 — 검색. TickersAPI.search() 비동기 호출 + debounce.
//  "최근 조회 종목" 영속화 — VerdictView 진입 시 자동 기록 (RecentTickersStore).
//

import SwiftUI

// MARK: - 최근 조회 종목 — VerdictView 진입 시 자동 기록, 검색 탭에서 노출.
// 검색어 텍스트가 아니라 실제로 상세 페이지를 본 종목만 누적. JSON 영속화.
struct RecentTickerItem: Codable, Equatable, Identifiable {
    let ticker: String
    let companyNameKr: String?
    var id: String { ticker }
}

enum RecentTickersStore {
    private static let key = "recent.viewed.v1"
    private static let maxCount = 10

    static func load() -> [RecentTickerItem] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let items = try? JSONDecoder().decode([RecentTickerItem].self, from: data)
        else { return [] }
        return items
    }

    static func save(_ items: [RecentTickerItem]) {
        let trimmed = Array(items.prefix(maxCount))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func add(ticker: String, companyNameKr: String?) {
        var items = load()
        items.removeAll { $0.ticker == ticker }   // 중복 제거 (최신 진입을 위로)
        items.insert(RecentTickerItem(ticker: ticker, companyNameKr: companyNameKr), at: 0)
        save(items)
    }

    static func remove(ticker: String) {
        var items = load()
        items.removeAll { $0.ticker == ticker }
        save(items)
    }

    static func clear() { save([]) }
}

struct SearchView: View {
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var results: [TickerSearchItem] = []
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?
    @State private var favoriteTickers: Set<String> = []
    // 최근 조회 종목 — VerdictView 가 write, 여기선 read. 탭 진입/돌아옴 시 refresh.
    @State private var recentViewed: [RecentTickerItem] = []

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    if recentViewed.isEmpty {
                        // 빈 상태 — Apple HIG 의 empty state 패턴 (아이콘 + 메시지 + 안내).
                        VStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("최근 조회한 종목이 없어요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("위 검색창에서 종목을 찾아보세요.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(recentViewed) { item in
                                NavigationLink {
                                    VerdictView(ticker: item.ticker)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18)
                                        VStack(alignment: .leading, spacing: 2) {
                                            // 회사명 (한글) 메인, 없으면 ticker fallback
                                            Text(item.companyNameKr ?? item.ticker)
                                                .font(.body)
                                                .foregroundStyle(Color(.label))
                                            Text(item.ticker)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        RecentTickersStore.remove(ticker: item.ticker)
                                        recentViewed = RecentTickersStore.load()
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("최근 조회 종목")
                                Spacer()
                                Button("전체 삭제") {
                                    RecentTickersStore.clear()
                                    recentViewed = []
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                            }
                        }
                    }

                } else {
                    Section("검색 결과 · \(results.count)건") {
                        if loading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        } else if results.isEmpty {
                            VStack(spacing: 8) {
                                Text("일치하는 종목이 없습니다")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("DB 미존재 시 수집을 요청할 수 있습니다.")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else {
                            ForEach(results) { item in
                                HStack(spacing: 8) {
                                    NavigationLink {
                                        VerdictView(ticker: item.ticker)
                                    } label: {
                                        TickerRow(
                                            symbol: item.ticker,
                                            nameKr: item.companyNameKr,
                                            price: nil,
                                            priceChangePct: nil,
                                            grade: nil,
                                            worstCasePct: nil
                                        )
                                    }
                                    if state.isAuthenticated {
                                        Button {
                                            Task { await toggleFavorite(item.ticker) }
                                        } label: {
                                            Image(systemName: favoriteTickers.contains(item.ticker)
                                                  ? "heart.fill" : "plus.circle")
                                                .foregroundStyle(favoriteTickers.contains(item.ticker)
                                                                  ? .red : Color(.label))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "티커 / 한글명 / 영문명")
            .task {
                await loadFavorites()
                recentViewed = RecentTickersStore.load()
            }
            // 다른 탭에서 verdict 본 후 검색 탭 돌아올 때 최신화.
            .onAppear {
                recentViewed = RecentTickersStore.load()
            }
            .onChange(of: query) { _, newValue in
                triggerSearch(newValue)
            }
        }
    }

    private func loadFavorites() async {
        guard state.isAuthenticated else { return }
        if let list = try? await WatchlistAPI.list() {
            self.favoriteTickers = Set(list.items.map { $0.ticker })
        }
    }

    private func toggleFavorite(_ ticker: String) async {
        let isFav = favoriteTickers.contains(ticker)
        if isFav {
            favoriteTickers.remove(ticker)   // optimistic
            do {
                _ = try await WatchlistAPI.remove(ticker: ticker)
            } catch {
                favoriteTickers.insert(ticker)   // rollback
            }
        } else {
            favoriteTickers.insert(ticker)
            do {
                _ = try await WatchlistAPI.add(ticker: ticker)
            } catch {
                favoriteTickers.remove(ticker)
            }
        }
    }

    // 300ms debounce — 빠른 타이핑 중 매번 호출 방지
    private func triggerSearch(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            loading = false
            return
        }
        loading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            do {
                let data = try await TickersAPI.search(query: trimmed, limit: 20)
                if !Task.isCancelled {
                    self.results = data.items
                    self.loading = false
                }
            } catch {
                if !Task.isCancelled {
                    self.results = []
                    self.loading = false
                }
            }
        }
    }
}

#Preview { SearchView() }
