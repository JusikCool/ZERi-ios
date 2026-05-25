//
//  AppRoot.swift
//  before
//
//  앱 진입 흐름:
//    Splash (0.5s) → Onboarding (첫 진입) → Terms (약관 미동의 시) → Main
//
//  isOnboarded / isAuthenticated / hasAgreedToTerms 는 UserDefaults 로 영속화.
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let isOnboarded = "isOnboarded"
        static let isAuthenticated = "isAuthenticated"
        static let hasAgreedToTerms = "hasAgreedToTerms"
    }

    enum Route {
        case splash
        case onboarding
        case terms       // 약관 동의 — onboarding 다음, main 이전
        case auth
        case main
    }

    @Published var isOnboarded: Bool {
        didSet { UserDefaults.standard.set(isOnboarded, forKey: Key.isOnboarded) }
    }
    @Published var isAuthenticated: Bool {
        didSet { UserDefaults.standard.set(isAuthenticated, forKey: Key.isAuthenticated) }
    }
    @Published var hasAgreedToTerms: Bool {
        didSet { UserDefaults.standard.set(hasAgreedToTerms, forKey: Key.hasAgreedToTerms) }
    }
    @Published var route: Route
    @Published var currentUser: UserPublic?

    /// 탭 선택 상태 — 다른 탭(예: 홈)에서 프로그래밍으로 검색 탭으로 전환할 때 사용.
    /// 0: 홈, 1: 검색, 2: 관심, 3: 마이.
    @Published var selectedTab: Int = 0

    /// 사용자 이름의 첫 글자 (프로필 버블용). 미로그인/이름 없을 시 "?".
    var userInitial: String {
        guard let name = currentUser?.name, let first = name.first else { return "?" }
        return String(first)
    }

    init() {
        let d = UserDefaults.standard
        self.isOnboarded = d.bool(forKey: Key.isOnboarded)
        self.isAuthenticated = d.bool(forKey: Key.isAuthenticated)
        self.hasAgreedToTerms = d.bool(forKey: Key.hasAgreedToTerms)
        self.route = .splash
    }

    func decideAfterSplash() {
        if !isOnboarded {
            route = .onboarding
        } else if !hasAgreedToTerms {
            route = .terms
        } else {
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
            case .terms:
                TermsGateView()
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
        .tint(Color(.label))    // 전역 액센트 → 검정 계열
    }
}

#Preview { AppRoot() }
