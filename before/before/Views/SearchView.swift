//
//  SearchView.swift
//  before
//
//  탭 2 — 검색. TickersAPI.search() 비동기 호출 + debounce.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var recent: [String] = []
    @State private var results: [TickerSearchItem] = []
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?
    @State private var favoriteTickers: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    if !recent.isEmpty {
                        Section("최근 검색") {
                            ForEach(recent, id: \.self) { q in
                                HStack {
                                    Image(systemName: "clock").foregroundStyle(.secondary)
                                    Text(q)
                                    Spacer()
                                    Button {
                                        recent.removeAll { $0 == q }
                                    } label: {
                                        Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { query = q }
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
                                                                  ? .red : .blue)
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
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "티커 / 한글명 / 영문명")
            .task {
                await loadFavorites()
            }
            .onChange(of: query) { _, newValue in
                triggerSearch(newValue)
            }
            .onSubmit(of: .search) {
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                if !recent.contains(trimmed) { recent.insert(trimmed, at: 0) }
                if recent.count > 5 { recent = Array(recent.prefix(5)) }
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
