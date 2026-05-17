//
//  APIError.swift
//  before
//
//  백엔드 에러 envelope (스펙 §0.2) 파싱 + 클라이언트 측 에러 케이스 통합.
//  성공/에러 둘 다 { data | error, meta } 형태.
//

import Foundation

/// 백엔드 envelope.error 본문.
struct APIErrorBody: Decodable {
    let code: String
    let message: String
    let details: [String: AnyCodable]?
}

struct APIErrorMeta: Decodable {
    let requestId: String?
    let ts: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case ts
    }
}

struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
    let meta: APIErrorMeta?
}

/// 클라이언트가 throw 하는 통합 에러.
enum APIError: Error, LocalizedError {
    /// 네트워크/연결 실패 — URLSession 단계 오류.
    case network(URLError)
    /// HTTP 4xx/5xx + 백엔드 envelope 파싱 성공.
    case server(status: Int, code: String, message: String, requestId: String?)
    /// HTTP 4xx/5xx 인데 envelope 파싱 실패 (서버 또는 프록시가 비표준 응답).
    case unexpectedResponse(status: Int, body: String?)
    /// JSON 디코딩 실패.
    case decoding(Error)
    /// 인증 만료 — 401 의 별칭. 호출자가 토큰 클리어/로그아웃 트리거.
    case unauthorized(message: String, requestId: String?)

    var errorDescription: String? {
        switch self {
        case .network(let err): return "네트워크 오류: \(err.localizedDescription)"
        case .server(_, _, let msg, _): return msg
        case .unexpectedResponse(let status, _): return "예기치 못한 응답 (\(status))"
        case .decoding: return "응답 형식이 예상과 다릅니다."
        case .unauthorized(let msg, _): return msg
        }
    }
}

/// URLResponse → APIError 변환 헬퍼.
enum APIErrorParser {
    static func parse(data: Data, response: HTTPURLResponse) -> APIError {
        if let envelope = try? JSONDecoder.api.decode(APIErrorEnvelope.self, from: data) {
            let body = envelope.error
            let reqId = envelope.meta?.requestId
            if response.statusCode == 401 {
                return .unauthorized(message: body.message, requestId: reqId)
            }
            return .server(
                status: response.statusCode,
                code: body.code,
                message: body.message,
                requestId: reqId
            )
        }
        let raw = String(data: data, encoding: .utf8)
        return .unexpectedResponse(status: response.statusCode, body: raw)
    }
}
