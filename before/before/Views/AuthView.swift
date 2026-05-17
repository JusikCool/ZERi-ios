//
//  AuthView.swift
//  before
//
//  로그인 / 회원가입 — AuthAPI 실제 호출.
//  signup 은 이름 추가 입력 시트로 분기.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var mode: Mode = .login
    @State private var loading = false
    @State private var errorMessage: String?

    enum Mode { case login, signup }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(mode == .login ? "로그인" : "회원가입")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 32)

                    Text(mode == .login
                         ? "이메일로 로그인하거나 새 계정을 만드세요"
                         : "이메일과 비밀번호로 가입하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if mode == .signup {
                        labeledField(label: "이름", placeholder: "유진") {
                            TextField("유진", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                        }
                    }

                    labeledField(label: "이메일", placeholder: "name@example.com") {
                        TextField("name@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }

                    labeledField(label: "비밀번호", placeholder: "8자 이상") {
                        SecureField("8자 이상", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if loading { ProgressView().tint(.white) }
                            Text(mode == .login ? "로그인" : "가입하기").font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(.label))
                    .controlSize(.large)
                    .disabled(loading || !canSubmit)
                    .padding(.top, 8)

                    HStack {
                        line
                        Text("또는").font(.caption).foregroundStyle(.secondary)
                        line
                    }
                    .padding(.vertical, 4)

                    // Apple 로그인 — 유료 Developer 계정 활성 후 연결. UI 만 노출.
                    socialButton(label: "Apple로 계속하기", color: Color(.label), text: .white, system: "applelogo")

                    HStack(spacing: 6) {
                        if mode == .login {
                            Text("처음이신가요?")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("회원가입") {
                                mode = .signup
                                errorMessage = nil
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                        } else {
                            Text("이미 계정이 있나요?")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("로그인") {
                                mode = .login
                                errorMessage = nil
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Text("로그인 시 서비스 이용약관, 개인정보 처리방침, 투자 정보 면책 고지에 동의한 것으로 간주합니다.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        state.route = .main
                    } label: {
                        Image(systemName: "chevron.left").foregroundStyle(Color(.label))
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, password.count >= 8 else { return false }
        if mode == .signup { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    private var line: some View {
        Rectangle().fill(Color(.separator)).frame(height: 0.5)
    }

    private func labeledField<Content: View>(
        label: String, placeholder: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func socialButton(label: String, color: Color, text: Color, system: String) -> some View {
        Button {
            // OAuth 흐름은 후속 — 발표용 데모는 통과 처리
            state.isAuthenticated = true
            state.route = .main
        } label: {
            HStack {
                Image(systemName: system)
                Text(label).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .background(color)
        .foregroundStyle(text)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Submit

    private func submit() async {
        loading = true
        errorMessage = nil
        do {
            let user: UserPublic
            switch mode {
            case .login:
                user = try await AuthAPI.login(email: email, password: password)
            case .signup:
                user = try await AuthAPI.signup(email: email, password: password, name: name)
            }
            state.currentUser = user
            state.isAuthenticated = true
            state.route = .main
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

#Preview { AuthView().environmentObject(AppState()) }
