//
//  AuthView.swift
//  before
//
//  로그인 / 회원가입 — Apple Sign-in 스타일 미니멀 디자인.
//  Soft-fill 텍스트필드, 아이콘 prefix, 비밀번호 show/hide, 큰 검정 CTA.
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
    @State private var passwordVisible = false
    @FocusState private var focusedField: Field?

    enum Mode { case login, signup }
    enum Field { case name, email, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Brand mark
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("before").font(.subheadline.weight(.semibold))
                        Text(".").font(.subheadline.weight(.semibold)).foregroundStyle(Color(.label))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                    // Title
                    Text(mode == .login ? "로그인" : "회원가입")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.bottom, 8)

                    Text(mode == .login
                         ? "계정에 로그인해서\n분석 기록을 이어가세요"
                         : "30초면 끝나요.\n이메일 하나로 시작합니다.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 36)

                    // Fields
                    VStack(spacing: 12) {
                        if mode == .signup {
                            CleanField(
                                icon: "person",
                                placeholder: "이름",
                                text: $name,
                                isSecure: false,
                                keyboardType: .default,
                                autocapitalization: .words,
                                focused: $focusedField,
                                fieldId: .name
                            )
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                        }

                        CleanField(
                            icon: "envelope",
                            placeholder: "이메일",
                            text: $email,
                            isSecure: false,
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                            focused: $focusedField,
                            fieldId: .email
                        )
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        CleanField(
                            icon: "lock",
                            placeholder: "비밀번호",
                            text: $password,
                            isSecure: !passwordVisible,
                            keyboardType: .default,
                            autocapitalization: .never,
                            focused: $focusedField,
                            fieldId: .password,
                            trailingIcon: passwordVisible ? "eye.slash" : "eye",
                            trailingAction: { passwordVisible.toggle() }
                        )
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                    }

                    if let msg = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text(msg).font(.caption)
                        }
                        .foregroundStyle(Color.riskRed)
                        .padding(.top, 12)
                    }

                    // Primary CTA
                    Button {
                        focusedField = nil
                        Task { await submit() }
                    } label: {
                        ZStack {
                            if loading {
                                ProgressView().tint(Color.brandOnPrimary)
                            } else {
                                Text(mode == .login ? "로그인" : "가입하기")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .foregroundStyle(Color.brandOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSubmit ? Color(.label) : Color(.label).opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(loading || !canSubmit)
                    .padding(.top, 24)

                    // OR divider
                    HStack(spacing: 12) {
                        line
                        Text("또는").font(.caption).foregroundStyle(.tertiary)
                        line
                    }
                    .padding(.vertical, 24)

                    // Apple — UI 더미
                    Button {
                        // 유료 Developer 계정 활성 후 OAuth 연결.
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "applelogo").font(.body)
                            Text("Apple로 계속하기").font(.body.weight(.medium))
                        }
                        .foregroundStyle(Color.brandOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.label))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 36)

                    // Mode toggle
                    HStack(spacing: 6) {
                        Text(mode == .login ? "처음이신가요?" : "이미 계정이 있나요?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = mode == .login ? .signup : .login
                                errorMessage = nil
                            }
                        } label: {
                            Text(mode == .login ? "회원가입" : "로그인")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(.label))
                                .underline()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    // Footnote
                    Text("계속 진행 시 [서비스 이용약관](https://example.com/terms)·[개인정보 처리방침](https://example.com/privacy)·투자 면책 고지에 동의한 것으로 간주합니다.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                        .tint(Color(.label))
                }
                .padding(.horizontal, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        state.route = .main
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color(.tertiarySystemBackground)))
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

    // MARK: - Submit

    private func submit() async {
        guard canSubmit else { return }
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

// MARK: - CleanField

private struct CleanField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    let focused: FocusState<AuthView.Field?>.Binding
    let fieldId: AuthView.Field
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isFocused ? Color(.label) : .secondary)
                .frame(width: 18)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            .textInputAutocapitalization(autocapitalization)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .focused(focused, equals: fieldId)

            if let trailingIcon, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color(.label) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var isFocused: Bool { focused.wrappedValue == fieldId }
}

#Preview { AuthView().environmentObject(AppState()) }
