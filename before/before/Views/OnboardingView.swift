//
//  OnboardingView.swift
//  before
//
//  서비스 가치 + 자본시장법 면책 사전 고지. "시작하기" 누르면 onboarded=true 처리.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("before").font(.system(size: 40, weight: .bold))
                Text(".").font(.system(size: 40, weight: .bold)).foregroundStyle(Color(.label))
            }
            .padding(.bottom, 28)

            Text("투자하기 전에\n한 번 더 확인하세요")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("종목의 통계적 변동성을 객관 지표로 알려드립니다.\n매수 권유나 수익 보장이 아닙니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(num: "01", title: "변동성 등급", desc: "높음 / 중간 / 보통 — 한눈에 파악")
                FeatureRow(num: "02", title: "핵심 변수", desc: "왜 이 등급인지 5개 변수로 설명")
                FeatureRow(num: "03", title: "과거 유사 패턴", desc: "비슷했던 시점의 사후 데이터")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)

            Spacer()

            Button {
                state.isOnboarded = true
                state.route = state.hasAgreedToTerms ? .main : .terms
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.label))
            .controlSize(.large)
            .padding(.horizontal, 28)

            Button {
                state.isOnboarded = true
                state.route = state.hasAgreedToTerms ? .auth : .terms
            } label: {
                Text("이미 계정이 있어요").font(.subheadline)
                    .foregroundStyle(Color(.label))
            }
            .padding(.top, 8)

            Text("시작 시 자본시장법 면책 고지에 동의한 것으로 간주합니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
    }
}

private struct FeatureRow: View {
    let num: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(num)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.label))
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview { OnboardingView().environmentObject(AppState()) }
