//
//  HTTPClient.swift
//  before
//
//  URLSession 기반 비동기 클라이언트.
//  ZERi-client/src/apis/http.ts 의 Swift 대응:
//    - baseURL: APIConfig.baseURL
//    - Bearer 자동 부착
//    - 401 → 토큰 클리어 + onUnauthorized 트리거
//    - JSON 인코딩/디코딩
//    - envelope.data 자동 언래핑 (ApiResponse<T> 의 data 추출)
//
//  사용:
//      let me: MeResponse = try await HTTPClient.shared.get(Endpoints.Me.profile)
//      let tokens: SignupResponse = try await HTTPClient.shared.post(
//          Endpoints.Auth.signup, body: signupRequest)
//

import Foundation

/// 백엔드 공통 envelope.data 컨테이너.
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let meta: APIErrorMeta?
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()
}

actor HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private var onUnauthorized: (@Sendable () -> Void)?

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = APIConfig.timeout
            config.timeoutIntervalForResource = APIConfig.timeout * 3
            self.session = URLSession(configuration: config)
        }
    }

    /// 401 토큰 만료 시 호출되는 콜백 등록 (앱 시작 시 1회).
    /// ZERi-client 의 setUnauthorizedHandler 대응.
    func setUnauthorizedHandler(_ handler: @escaping @Sendable () -> Void) {
        self.onUnauthorized = handler
    }

    // MARK: - Public verbs

    func get<R: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> R {
        try await send(method: "GET", path: path, query: query, body: Optional<Empty>.none)
    }

    func post<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await send(method: "POST", path: path, query: [:], body: body)
    }

    func post<R: Decodable>(_ path: String) async throws -> R {
        try await send(method: "POST", path: path, query: [:], body: Optional<Empty>.none)
    }

    func patch<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await send(method: "PATCH", path: path, query: [:], body: body)
    }

    func delete<R: Decodable>(_ path: String) async throws -> R {
        try await send(method: "DELETE", path: path, query: [:], body: Optional<Empty>.none)
    }

    // MARK: - Core

    private struct Empty: Encodable {}

    private func send<B: Encodable, R: Decodable>(
        method: String,
        path: String,
        query: [String: String],
        body: B?
    ) async throws -> R {
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = TokenStore.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder.api.encode(body)
            } catch {
                throw APIError.decoding(error)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlErr as URLError {
            throw APIError.network(urlErr)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse(status: -1, body: String(data: data, encoding: .utf8))
        }

        if !(200..<300).contains(http.statusCode) {
            let apiErr = APIErrorParser.parse(data: data, response: http)
            if case .unauthorized = apiErr {
                TokenStore.clearAllTokens()
                onUnauthorized?()
            }
            throw apiErr
        }

        do {
            let envelope = try JSONDecoder.api.decode(APIResponse<R>.self, from: data)
            return envelope.data
        } catch {
            throw APIError.decoding(error)
        }
    }
}
