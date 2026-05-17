//
//  WatchlistManageView.swift
//  before
//
//  관심 종목 관리 화면.
//  List + 스와이프 삭제 + EditButton + 빈 상태 안내 + 검색 시트로 추가.
//

import SwiftUI

struct WatchlistManageView: View {
    @EnvironmentObject var state: AppState
    @State private var items: [WatchlistItem] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showAddSheet = false

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !state.isAuthenticated {
                guestPrompt
            } else if items.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(items) { item in
                            NavigationLink {
                                VerdictView(ticker: item.ticker)
                            } label: {
                                row(item)
                            }
                        }
                        .onDelete(perform: remove)
                    } header: {
                        HStack {
                            Text("등록된 종목")
                            Spacer()
                            Text("\(items.count) / 30")
                                .font(.caption2).foregroundStyle(.tertiary)
                                .textCase(nil)
                        }
                    } footer: {
                        Text("관심 종목의 변동성 등급이 바뀌면 푸시로 알려드립니다. 매수·매도 신호가 아닌 통계 변동성 변화 알림입니다.")
                            .font(.caption2)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("관심 종목")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if state.isAuthenticated {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            Task { await load() }
        }) {
            NavigationStack {
                SearchView()
                    .navigationTitle("종목 추가")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("완료") { showAddSheet = false }
                        }
                    }
            }
        }
        .alert("오류", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("확인") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Components

    private func row(_ item: WatchlistItem) -> some View {
        HStack(spacing: 12) {
            Text(item.ticker)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(Color(.label))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 60, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.companyNameKr ?? item.ticker)
                    .font(.body.weight(.semibold))
                if let sector = item.sector {
                    Text(sector).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var guestPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("로그인하면 관심 종목을\n저장하고 알림을 받을 수 있어요")
                .font(.headline)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("아직 관심 종목이 없어요")
                .font(.headline)
            Text("검색에서 종목을 찾아 추가하거나\n상세 화면의 ♡ 버튼으로 등록하세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("종목 검색해서 추가", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.label))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func load() async {
        guard state.isAuthenticated else {
            self.items = []
            self.loading = false
            return
        }
        loading = true
        do {
            let data = try await WatchlistAPI.list()
            self.items = data.items
        } catch {
            self.errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func remove(at offsets: IndexSet) {
        let toRemove = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        Task {
            for item in toRemove {
                do {
                    _ = try await WatchlistAPI.remove(ticker: item.ticker)
                } catch {
                    // 실패 시 다시 불러와 정합성 회복
                    await load()
                    return
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchlistManageView().environmentObject(AppState())
    }
}
