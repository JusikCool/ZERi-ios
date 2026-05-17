//
//  AppRoot.swift
//  before
//
//  앱 진입 흐름 컨트롤러:
//    Splash (0.5s)  →  (첫 진입이면) Onboarding → Auth (옵션) → Main
//                   →  (재진입이면) Main
//
//  isOnboarded / isAuthenticated 는 UserDefaults 로 영속화.
//  (@AppStorage 는 ObservableObject 안에서 동작 안 함 — View 전용)
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let isOnboarded = "isOnboarded"
        static let isAuthenticated = "isAuthenticated"
    }

    enum Route {
        case splash
        case onboarding
        case auth
        case main
    }

    @Published var isOnboarded: Bool {
        didSet { UserDefaults.standard.set(isOnboarded, forKey: Key.isOnboarded) }
    }
    @Published var isAuthenticated: Bool {
        didSet { UserDefaults.standard.set(isAuthenticated, forKey: Key.isAuthenticated) }
    }
    @Published var route: Route
    @Published var currentUser: UserPublic?

    /// 사용자 이름의 첫 글자 (프로필 버블용). 미로그인/이름 없을 시 "?".
    var userInitial: String {
        guard let name = currentUser?.name, let first = name.first else { return "?" }
        return String(first)
    }

    init() {
        let d = UserDefaults.standard
        self.isOnboarded = d.bool(forKey: Key.isOnboarded)
        self.isAuthenticated = d.bool(forKey: Key.isAuthenticated)
        self.route = .splash
    }

    func decideAfterSplash() {
        if !isOnboarded {
            route = .onboarding
        } else {
            // 로그인 안 했어도 게스트로 spotlight/search 가능
            route = .main
        }
    }

    /// 로그인 직후 또는 앱 시작 시 호출. 실패해도 로그아웃 안 시킴 (401 시 HTTPClient 가 처리).
    func loadCurrentUser() async {
        guard isAuthenticated else {
            self.currentUser = nil
            return
        }
        if let user = try? await MeAPI.profile() {
            self.currentUser = user
        }
    }
}

struct AppRoot: View {
    @StateObject private var state = AppState()

    var body: some View {
        ZStack {
            switch state.route {
            case .splash:
                SplashView()
                    .task {
                        // 토큰 만료 / 비정상 401 시 자동 로그아웃 + auth 화면으로
                        await HTTPClient.shared.setUnauthorizedHandler {
                            Task { @MainActor in
                                state.isAuthenticated = false
                                state.currentUser = nil
                                state.route = .auth
                            }
                        }
                        // 인증 상태면 프로필 미리 로드 (백그라운드)
                        Task { await state.loadCurrentUser() }
                        try? await Task.sleep(nanoseconds: 500_000_000)   // 0.5s
                        state.decideAfterSplash()
                    }
            case .onboarding:
                OnboardingView()
                    .environmentObject(state)
            case .auth:
                AuthView()
                    .environmentObject(state)
            case .main:
                MainTabView()
                    .environmentObject(state)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.route)
    }
}

#Preview { AppRoot() }
