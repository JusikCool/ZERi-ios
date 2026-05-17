//
//  MainTabView.swift
//  before
//
//  4개 탭: 홈 · 검색 · 기록 · 마이.
//  iOS 기본 TabView + 시스템 아이콘 (SF Symbols).
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }

            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }

            HistoryView()
                .tabItem { Label("기록", systemImage: "list.bullet") }

            MyPageView()
                .tabItem { Label("마이", systemImage: "person.fill") }
        }
        .tint(Color(.label))
    }
}

#Preview { MainTabView().environmentObject(AppState()) }
