//
//  SplashView.swift
//  before
//
//  0.5초 로고 노출 후 AppRoot 가 자동 전환.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("before")
                        .font(.system(size: 56, weight: .bold, design: .default))
                        .foregroundStyle(Color(.label))
                    Text(".")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

#Preview { SplashView() }
