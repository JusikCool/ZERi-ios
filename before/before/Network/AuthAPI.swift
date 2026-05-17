//
//  AuthAPI.swift
//  before
//
//  signup / login / refresh / logout 흐름.
//  성공 시 TokenStore 에 자동 저장.
//

import Foundation

enum AuthAPI {
    /// 회원가입 + 면책 동의 동시 기록. 성공 시 토큰 페어 자동 저장.
    static func signup(
        email: String,
        password: String,
        name: String,
        disclaimerCode: String = "MAIN_V1"
    ) async throws -> UserPublic {
        let req = SignupRequest(
            email: email, password: password, name: name, disclaimerCode: disclaimerCode
        )
        let res: SignupResponse = try await HTTPClient.shared.post(Endpoints.Auth.signup, body: req)
        TokenStore.saveTokens(access: res.tokens.accessToken, refresh: res.tokens.refreshToken)
        return res.user
    }

    /// 이메일+비밀번호 로그인. 성공 시 토큰 페어 자동 저장.
    static func login(email: String, password: String) async throws -> UserPublic {
        let req = LoginRequest(email: email, password: password)
        let res: LoginResponse = try await HTTPClient.shared.post(Endpoints.Auth.login, body: req)
        TokenStore.saveTokens(access: res.tokens.accessToken, refresh: res.tokens.refreshToken)
        return res.user
    }

    /// refresh 회전. 성공 시 새 페어 저장.
    @discardableResult
    static func refresh() async throws -> TokenPair {
        guard let refresh = TokenStore.getRefreshToken() else {
            throw APIError.unauthorized(message: "refresh 토큰이 없습니다.", requestId: nil)
        }
        let req = RefreshRequest(refreshToken: refresh)
        let res: RefreshResponse = try await HTTPClient.shared.post(Endpoints.Auth.refresh, body: req)
        TokenStore.saveTokens(access: res.tokens.accessToken, refresh: res.tokens.refreshToken)
        return res.tokens
    }

    /// 로그아웃 — 서버측 refresh 무력화 + 로컬 토큰 클리어.
    static func logout() async throws {
        if let refresh = TokenStore.getRefreshToken() {
            let req = LogoutRequest(refreshToken: refresh)
            _ = try? await HTTPClient.shared.post(Endpoints.Auth.logout, body: req) as LogoutResponse
        }
        TokenStore.clearAllTokens()
    }
}
