//
//  MyPageView.swift
//  before
//
//  탭 4 — 마이. 프로필 + 분석 통계 + 모델 정직성 + 설정 메뉴.
//  iOS Settings 앱 느낌으로 List(.insetGrouped) 활용.
//

import SwiftUI

struct MyPageView: View {
    @EnvironmentObject var state: AppState
    @State private var profile: UserPublic?
    @State private var stats: HistoryStatsData?

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section {
                    if state.isAuthenticated, let user = profile {
                        userRow(user)
                    } else if state.isAuthenticated {
                        HStack {
                            ProgressView()
                            Text("프로필 로딩 중...")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        guestRow
                    }
                }

                // 분석 통계
                if state.isAuthenticated {
                    Section {
                        statsRowReal(grade: "VOLATILITY_HIGH")
                        statsRowReal(grade: "VOLATILITY_MID")
                        statsRowReal(grade: "VOLATILITY_LOW")
                    } header: {
                        HStack {
                            Text("내 분석 통계")
                            Spacer()
                            if let s = stats {
                                let totalDone = s.byOutcome.values.reduce(0, +)
                                let evaluated = totalDone - (s.byOutcome["pending"] ?? 0)
                                Text("전체 \(s.totalAnalyses)건 · 평가 \(evaluated)건")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .textCase(nil)
                            }
                        }
                    } footer: {
                        Text("모델 등급별 과거 사후 빈도이며, 미래 결과·매수매도 판단·손실 회피 어느 것도 보장하지 않습니다.")
                            .font(.caption2)
                    }
                }

                // 모델 정직성 — 실 데이터 누적 후 공개 (D+30 이후)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("데이터 누적 중")
                            .font(.subheadline.weight(.semibold))
                        Text("서비스 출시 30일 후부터 실제 적중률과 통계 검정 결과를 공개합니다. 그 전에는 추정값을 보여드리지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("모델 정직성")
                }

                // 설정
                Section("설정") {
                    // 관심 종목 관리는 탭으로 승격 — 여기선 제거, 대신 분석 기록 진입.
                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Label("분석 기록", systemImage: "list.bullet.rectangle")
                            Spacer()
                            Text("verdict 조회 이력").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack {
                            Label("알림 설정", systemImage: "bell")
                            Spacer()
                            Text("위험도 상승 시 푸시").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        TermsHistoryView()
                    } label: {
                        HStack {
                            Label("약관 및 면책 동의 이력", systemImage: "doc.text")
                            Spacer()
                            Text("\(TermsConsentStore.loadAll().count)건 동의").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if state.isAuthenticated {
                        Button(role: .destructive) {
                            Task {
                                try? await AuthAPI.logout()
                                state.isAuthenticated = false
                                state.currentUser = nil
                                state.route = .auth
                            }
                        } label: {
                            Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button {
                            state.route = .auth
                        } label: {
                            Label("로그인 / 회원가입", systemImage: "person.crop.circle.badge.plus")
                                .foregroundStyle(Color(.label))
                        }
                    }
                }

                // Disclaimer
                Section {
                    Text("본 서비스는 투자자문업 등록 사업자가 아니며, 통계 모델에 기반한 정보 제공만을 목적으로 합니다. 특정 종목의 매수·매도를 권유하지 않으며, 과거 통계는 미래 결과를 보장하지 않습니다. 투자 판단과 그 결과에 따른 손실은 투자자 본인에게 귀속됩니다.")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.large)
            .task(id: state.isAuthenticated) { await reload() }
            .refreshable { await reload() }
        }
    }

    // MARK: - Profile rows

    private func userRow(_ user: UserPublic) -> some View {
        let initial = user.name.first.map { String($0) } ?? "?"
        let daysSince = daysSinceCreated(user.createdAt)
        return HStack(spacing: 12) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 48, height: 48)
                .overlay(Text(initial).font(.title3.weight(.bold)).foregroundStyle(Color(.label)))
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline)
                Text("\(user.email)\(daysSince.map { " · 가입 \($0)일째" } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var guestRow: some View {
        Button {
            state.route = .auth
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "person").foregroundStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text("로그인 / 회원가입").font(.headline)
                    Text("종목 분석 기록 + 워치리스트 저장")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats rows (real)

    @ViewBuilder
    private func statsRowReal(grade: String) -> some View {
        let g = stats?.byGradeOutcome[grade] ?? [:]
        let total = g.values.reduce(0, +)
        let downCount = g["price_dropped"] ?? 0
        let ratio = total > 0 ? Double(downCount) / Double(total) : 0

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RiskBadge(grade: grade, compact: true)
                Spacer()
                Text("\(total)건 중 30일 내 하락 ")
                    .font(.caption).foregroundStyle(.secondary)
                + Text("\(downCount)건")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.riskRed)
            }
            ProgressView(value: ratio).tint(.red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Load

    private func reload() async {
        guard state.isAuthenticated else {
            self.profile = nil
            self.stats = nil
            return
        }
        async let p = try? MeAPI.profile()
        async let s = try? HistoryAPI.stats()
        let user = await p
        self.profile = user
        if let user = user { state.currentUser = user }   // 전역 동기화
        self.stats = await s
    }

    private func daysSinceCreated(_ iso: String) -> Int? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day
        }
        return nil
    }
}

#Preview { MyPageView().environmentObject(AppState()) }
