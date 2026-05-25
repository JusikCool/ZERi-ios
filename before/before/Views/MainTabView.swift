//
//  MainTabView.swift
//  before
//
//  4개 탭: 홈 · 검색 · 관심 · 마이.
//  iOS 기본 TabView + 시스템 아이콘 (SF Symbols).
//  분석 기록(HistoryView) 은 마이 탭 안의 NavigationLink 로 접근.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
                .tag(1)

            // 관심 종목 탭 — 비로그인 시 guestPrompt, 로그인 시 워치리스트 관리.
            // NavigationStack 필수: NavigationLink/.navigationTitle/.toolbar 작동에 필요.
            NavigationStack {
                WatchlistManageView()
            }
            .tabItem { Label("관심", systemImage: "heart.fill") }
            .tag(2)

            MyPageView()
                .tabItem { Label("마이", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Color(.label))
    }
}

#Preview { MainTabView().environmentObject(AppState()) }
