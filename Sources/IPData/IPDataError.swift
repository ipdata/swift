import Foundation

/// Errors returned by the ipdata API or the client.
public enum IPDataError: Error, @unchecked Sendable, CustomStringConvertible {
    /// 400 – The request was malformed (invalid IP, private IP, bad JSON, etc.).
    case badRequest(String)
    /// 401 – Invalid or missing API key.
    case unauthorized(String)
    /// 403 – Quota exceeded, feature restricted, or IP/domain not whitelisted.
    case forbidden(String)
    /// 404 – The requested resource was not found (e.g. unknown ASN).
    case notFound(String)
    /// An unexpected HTTP status code was returned.
    case unexpectedStatus(statusCode: Int, message: String)
    /// The response body could not be decoded.
    case decodingFailed(Error)
    /// A network or URL-level error occurred.
    case networkError(Error)

    public var description: String {
        switch self {
        case .badRequest(let msg):       return "Bad Request: \(msg)"
        case .unauthorized(let msg):     return "Unauthorized: \(msg)"
        case .forbidden(let msg):        return "Forbidden: \(msg)"
        case .notFound(let msg):         return "Not Found: \(msg)"
        case .unexpectedStatus(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingFailed(let err):   return "Decoding failed: \(err.localizedDescription)"
        case .networkError(let err):     return "Network error: \(err.localizedDescription)"
        }
    }
}

/// Error body returned by the ipdata API.
struct APIErrorResponse: Codable, Sendable {
    let message: String
}
