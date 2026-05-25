//
//  TermsHistoryView.swift
//  before
//
//  마이페이지 → 약관 및 면책 동의 이력.
//  TermsConsentStore 에서 로컬 저장 데이터 불러와 표시.
//

import SwiftUI

struct TermsHistoryView: View {
    @State private var consents: [TermsConsentStore.Consent] = []
    @State private var detailKey: TermsKey?

    var body: some View {
        List {
            Section {
                if consents.isEmpty {
                    emptyState
                } else {
                    ForEach(consents) { c in
                        Button {
                            if let key = TermsKey(rawValue: c.id) {
                                detailKey = key
                            }
                        } label: {
                            row(c)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("동의 이력")
            } footer: {
                Text("회원 가입 시점 또는 약관 개정 시 동의한 기록이 표시됩니다. 항목을 눌러 전문을 다시 확인할 수 있습니다.")
                    .font(.caption2)
            }

            Section("현재 시행 약관") {
                ForEach(TermsKey.allCases) { key in
                    Button {
                        detailKey = key
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key.title).font(.body)
                                Text("\(key.version) · 시행 \(key.effectiveDate)")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("약관 동의 이력")
        .navigationBarTitleDisplayMode(.large)
        .task { reload() }
        .sheet(item: $detailKey) { key in
            TermsDetailSheet(termsKey: key)
        }
    }

    private func row(_ c: TermsConsentStore.Consent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(Color(.label))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(c.version).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(formattedDate(c.agreedAt)) 동의").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("동의 이력 없음")
                .font(.headline)
            Text("아직 약관에 동의한 기록이 없습니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func reload() {
        consents = TermsConsentStore.loadAll().sorted { $0.agreedAt > $1.agreedAt }
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월 d일 HH:mm"
        return f.string(from: d)
    }
}

#Preview {
    NavigationStack { TermsHistoryView() }
}
