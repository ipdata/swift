import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client for the ipdata.co IP Geolocation & Threat Intelligence API.
///
/// Uses only `Foundation` — no third-party dependencies.
///
/// ```swift
/// let client = IPDataClient(apiKey: "YOUR_API_KEY")
/// let info = try await client.lookup("8.8.8.8")
/// print(info.city ?? "unknown")
/// ```
public final class IPDataClient: @unchecked Sendable {

    /// The base URL for the standard API.
    public static let defaultBaseURL = URL(string: "https://api.ipdata.co")!
    /// The base URL for the EU-only endpoint.
    public static let euBaseURL = URL(string: "https://eu-api.ipdata.co")!

    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    /// Creates a new client.
    ///
    /// - Parameters:
    ///   - apiKey: Your ipdata API key.
    ///   - baseURL: Override the base URL (defaults to `https://api.ipdata.co`).
    ///              Use ``euBaseURL`` to route through EU servers only.
    ///   - session: A custom `URLSession` if needed (e.g. for testing).
    public init(
        apiKey: String,
        baseURL: URL = IPDataClient.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - IP Lookup

    /// Look up the calling device's IP address.
    ///
    /// - Parameter fields: Optional list of fields to return (e.g. `["ip", "city", "country_name"]`).
    /// - Returns: An ``IPResponse`` populated with the requested (or all) fields.
    public func lookup(fields: [String]? = nil) async throws -> IPResponse {
        let url = buildURL(path: "/", fields: fields)
        return try await fetch(url)
    }

    /// Look up a specific IP address.
    ///
    /// - Parameters:
    ///   - ip: An IPv4 or IPv6 address string.
    ///   - fields: Optional list of fields to return.
    /// - Returns: An ``IPResponse`` populated with the requested (or all) fields.
    public func lookup(_ ip: String, fields: [String]? = nil) async throws -> IPResponse {
        let url = buildURL(path: "/\(ip)", fields: fields)
        return try await fetch(url)
    }

    /// Look up a single field for a specific IP address.
    ///
    /// - Parameters:
    ///   - ip: An IPv4 or IPv6 address string.
    ///   - field: The field name to return (e.g. `"asn"`, `"threat"`, `"currency"`).
    /// - Returns: The raw `Data` of the JSON response for that field.
    public func lookupField(_ ip: String, field: String) async throws -> Data {
        let url = buildURL(path: "/\(ip)/\(field)")
        return try await fetchRaw(url)
    }

    // MARK: - Bulk Lookup

    /// Look up multiple IP addresses in a single request (max 100).
    ///
    /// - Parameters:
    ///   - ips: An array of IPv4/IPv6 address strings (1–100).
    ///   - fields: Optional list of fields to return.
    /// - Returns: An array of ``IPResponse`` results, one per IP.
    public func bulkLookup(_ ips: [String], fields: [String]? = nil) async throws -> [IPResponse] {
        var url = buildURL(path: "/bulk", fields: fields)
        // For bulk, the api-key must be a query parameter
        if !url.absoluteString.contains("api-key") {
            url = appendAPIKey(to: url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONEncoder().encode(ips)

        return try await perform(request)
    }

    // MARK: - ASN Lookup

    /// Look up detailed information for an Autonomous System Number.
    ///
    /// - Parameter asn: The AS number, e.g. `"AS15169"` or `"AS2"`.
    /// - Returns: An ``ASNDetail`` with prefixes, peers, upstreams, etc.
    public func lookupASN(_ asn: String) async throws -> ASNDetail {
        let normalized = asn.uppercased().hasPrefix("AS") ? asn : "AS\(asn)"
        let url = buildURL(path: "/\(normalized)")
        return try await fetch(url)
    }

    // MARK: - Internals

    private func buildURL(path: String, fields: [String]? = nil) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "api-key", value: apiKey)]
        if let fields, !fields.isEmpty {
            queryItems.append(URLQueryItem(name: "fields", value: fields.joined(separator: ",")))
        }
        components.queryItems = queryItems
        return components.url!
    }

    private func appendAPIKey(to url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "api-key", value: apiKey))
        components.queryItems = items
        return components.url!
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        return try await perform(request)
    }

    private func fetchRaw(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        let (data, response) = try await dataTask(request)
        try checkResponse(response, data: data)
        return data
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await dataTask(request)
        try checkResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw IPDataError.decodingFailed(error)
        }
    }

    private func dataTask(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw IPDataError.networkError(error)
        }
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            switch http.statusCode {
            case 400: throw IPDataError.badRequest(message)
            case 401: throw IPDataError.unauthorized(message)
            case 403: throw IPDataError.forbidden(message)
            case 404: throw IPDataError.notFound(message)
            default:  throw IPDataError.unexpectedStatus(statusCode: http.statusCode, message: message)
            }
        }
    }
}

// MARK: - Linux Async Compatibility

#if canImport(FoundationNetworking)
extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            task.resume()
        }
    }
}
#endif
