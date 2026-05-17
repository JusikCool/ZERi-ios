//
//  TokenStore.swift
//  before
//
//  Access / refresh 토큰을 Keychain 에 안전 저장.
//  ZERi-client/src/apis/auth.ts 의 localStorage 대응.
//

import Foundation
import Security

enum TokenStore {
    private static let service = "app.before.tokens"
    private static let accessKey = "access_token"
    private static let refreshKey = "refresh_token"

    static func saveTokens(access: String, refresh: String) {
        set(accessKey, value: access)
        set(refreshKey, value: refresh)
    }

    static func getAccessToken() -> String? { get(accessKey) }
    static func getRefreshToken() -> String? { get(refreshKey) }

    static func clearAllTokens() {
        delete(accessKey)
        delete(refreshKey)
    }

    // MARK: - Keychain helpers

    private static func set(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
