//
//  TermsGateView.swift
//  before
//
//  첫 진입 시 약관 동의. Onboarding 완료 후 main 진입 전 1회 통과.
//  3개 약관 모두 동의해야 진행 가능. 각 항목 탭 시 본문 sheet.
//  동의 시점·버전을 UserDefaults 에 저장 → 마이페이지 "동의 이력" 에서 조회.
//

import SwiftUI

struct TermsGateView: View {
    @EnvironmentObject var state: AppState
    @State private var agreed: Set<TermsKey> = []
    @State private var detailKey: TermsKey?

    private var allAgreed: Bool {
        agreed.count == TermsKey.allCases.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    masterToggle
                    Divider().padding(.vertical, 4)
                    ForEach(TermsKey.allCases) { key in
                        termRow(key)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            Divider()
            footer
        }
        .background(Color(.systemBackground))
        .sheet(item: $detailKey) { key in
            TermsDetailSheet(termsKey: key)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("서비스 이용 전")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("아래 약관에 동의해주세요")
                .font(.title2.weight(.bold))
            Text("ZERi 는 투자자문업이 아니며, 통계 모델 기반의 정보를 제공합니다. 각 항목을 눌러 전문을 확인하실 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var masterToggle: some View {
        Button {
            if allAgreed {
                agreed = []
            } else {
                agreed = Set(TermsKey.allCases)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: allAgreed ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(allAgreed ? Color(.label) : Color.secondary)
                Text("전체 동의")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
            }
            .padding(14)
            .background(allAgreed ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(allAgreed ? Color(.label) : Color.secondary.opacity(0.25),
                            lineWidth: allAgreed ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func termRow(_ key: TermsKey) -> some View {
        let isChecked = agreed.contains(key)
        return HStack(alignment: .top, spacing: 12) {
            Button {
                toggle(key)
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Color(.label) : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Button {
                detailKey = key
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("[필수]")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.riskRed)
                        Text(key.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(key.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                proceed()
            } label: {
                Text(allAgreed ? "동의하고 시작하기" : "모든 약관에 동의해주세요")
                    .font(.headline)
                    .foregroundStyle(allAgreed ? Color.brandOnPrimary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(allAgreed ? Color.brandPrimary : Color(.tertiarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!allAgreed)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func toggle(_ key: TermsKey) {
        if agreed.contains(key) { agreed.remove(key) }
        else { agreed.insert(key) }
    }

    private func proceed() {
        guard allAgreed else { return }
        TermsConsentStore.recordAll()
        state.hasAgreedToTerms = true
        state.route = state.isAuthenticated ? .main : .main
    }
}

// MARK: - Detail Sheet

struct TermsDetailSheet: View {
    let termsKey: TermsKey
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(termsKey.title)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 8) {
                            Text(termsKey.version)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("시행 \(termsKey.effectiveDate)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.bottom, 8)

                    Text(termsKey.body)
                        .font(.callout)
                        .foregroundStyle(Color(.label))
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(termsKey.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(Color(.label))
                }
            }
        }
    }
}

// MARK: - 동의 이력 저장소

enum TermsConsentStore {
    private static let key = "termsConsents"

    struct Consent: Codable, Identifiable {
        let id: String          // TermsKey.rawValue
        let title: String
        let version: String
        let agreedAt: Date
    }

    static func recordAll() {
        let now = Date()
        let items = TermsKey.allCases.map {
            Consent(id: $0.rawValue, title: $0.title, version: $0.version, agreedAt: now)
        }
        save(items)
    }

    static func loadAll() -> [Consent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([Consent].self, from: data)
        else { return [] }
        return items
    }

    private static func save(_ items: [Consent]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

#Preview {
    TermsGateView().environmentObject(AppState())
}
