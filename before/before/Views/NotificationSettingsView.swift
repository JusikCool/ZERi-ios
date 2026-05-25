//
//  NotificationSettingsView.swift
//  before
//
//  마이페이지 → 알림 설정.
//  로컬 토글만 (UserDefaults). 실제 APNs 연동은 v1.1.
//

import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notif.master") private var masterOn = true
    @AppStorage("notif.riskUp") private var riskUpOn = true
    @AppStorage("notif.gradeChange") private var gradeChangeOn = true
    @AppStorage("notif.dailySpotlight") private var dailySpotlightOn = false
    @AppStorage("notif.marketing") private var marketingOn = false

    var body: some View {
        List {
            // Master
            Section {
                Toggle(isOn: $masterOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("푸시 알림 전체").font(.body.weight(.semibold))
                        Text(masterOn ? "켜져있음 — 아래 항목별로 세부 조정" : "꺼짐 — 모든 알림 차단")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(Color(.label))
            } footer: {
                Text("실제 푸시 알림은 정식 출시 후 활성화됩니다. 지금은 설정값만 저장됩니다.")
                    .font(.caption2)
            }

            // 위험 관련
            Section("위험 알림") {
                row(
                    title: "위험도 상승 시 알림",
                    sub: "관심 종목의 30일 최악값이 5% 이상 악화될 때",
                    icon: "arrow.down.right.circle.fill",
                    iconColor: .red,
                    isOn: $riskUpOn
                )
                .disabled(!masterOn)

                row(
                    title: "등급 변경",
                    sub: "관심 종목의 변동성 등급이 한 단계 이상 바뀔 때",
                    icon: "arrow.up.arrow.down.circle.fill",
                    iconColor: Color(.label),
                    isOn: $gradeChangeOn
                )
                .disabled(!masterOn)
            }

            // 정보성
            Section("정보 알림") {
                row(
                    title: "매일 spotlight",
                    sub: "매일 아침 가장 위험한 종목 한 줄 요약",
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    isOn: $dailySpotlightOn
                )
                .disabled(!masterOn)

                row(
                    title: "이벤트 / 업데이트",
                    sub: "신기능, 점검 안내 등 회사 공지",
                    icon: "megaphone.fill",
                    iconColor: Color(.label),
                    isOn: $marketingOn
                )
                .disabled(!masterOn)
            }

            // 안내
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("푸시 권한").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("iOS 시스템 설정에서 ZERi 의 알림 권한을 켜두셔야 푸시가 도착합니다.")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("iOS 설정 열기 ›")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.label))
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.large)
    }

    private func row(title: String, sub: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(sub).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .tint(Color(.label))
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
}
