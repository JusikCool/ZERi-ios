//
//  APIConfig.swift
//  before
//
//  baseURL / timeout 등 환경 설정.
//  Info.plist 의 `API_BASE_URL` / `API_TIMEOUT_MS` 키에서 읽되, 미설정 시 폴백.
//
//  Info.plist 에 추가:
//    <key>API_BASE_URL</key>
//    <string>http://3.34.46.157:8000</string>
//    <key>API_TIMEOUT_MS</key>
//    <string>10000</string>
//

import Foundation

enum APIConfig {
    /// 백엔드 base URL — 운영은 https://jusikcool.duckdns.org (Caddy + Let's Encrypt).
    /// Info.plist 의 `API_BASE_URL` 우선, 미설정 시 운영 값으로 폴백.
    static let baseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? "https://jusikcool.duckdns.org"
        guard let url = URL(string: raw) else {
            fatalError("Invalid API_BASE_URL: \(raw)")
        }
        return url
    }()

    /// 요청 timeout (초).
    static let timeout: TimeInterval = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_TIMEOUT_MS") as? String) ?? "10000"
        return TimeInterval(Int(raw) ?? 10000) / 1000.0
    }()
}
