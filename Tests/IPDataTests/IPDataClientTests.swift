import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import IPData

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    /// Number of requests that reached this protocol since the counter was last reset.
    /// The protocol is registered only on the session injected into the client under
    /// test, so every request counted here went through that one session.
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requestCount += 1
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("No request handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

/// The body of a request captured by `MockURLProtocol`.
///
/// On Apple platforms `URLSession` hands the body to a `URLProtocol` as
/// `httpBodyStream` and leaves `httpBody` nil; on Linux `httpBody` is set.
private func requestBody(of request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }
    stream.open()
    defer { stream.close() }
    var collected = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        collected.append(buffer, count: read)
    }
    return collected
}

/// A 200 response carrying `json`, for use inside a request handler.
private func okResponse(for request: URLRequest, json: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (response, json.data(using: .utf8)!)
}

/// A session configuration that routes every request to `MockURLProtocol`.
private func mockConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return config
}

// MARK: - Client Tests

final class IPDataClientTests: XCTestCase {

    private var session: URLSession!
    private var client: IPDataClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestCount = 0
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = IPDataClient(apiKey: "test-api-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
        session = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Request Building

    func testLookupIPSendsCorrectRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url!.path.contains("/8.8.8.8"))
            XCTAssertTrue(request.url!.query!.contains("api-key=test-api-key"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"ip": "8.8.8.8"}"#.data(using: .utf8)!
            return (response, data)
        }

        let info = try await client.lookup("8.8.8.8")
        XCTAssertEqual(info.ip, "8.8.8.8")
    }

    func testLookupCurrentIPSendsCorrectPath() async throws {
        MockURLProtocol.requestHandler = { request in
            // Path should end with / (no IP specified)
            let path = request.url!.path
            XCTAssertTrue(path.hasSuffix("/"), "Path should be root: \(path)")
            XCTAssertFalse(path.contains("8.8.8.8"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"ip": "203.0.113.1"}"#.data(using: .utf8)!
            return (response, data)
        }

        let info = try await client.lookup()
        XCTAssertEqual(info.ip, "203.0.113.1")
    }

    func testLookupWithFieldsParameter() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = request.url!.query!
            XCTAssertTrue(query.contains("fields=ip,city,country_name"), "Query: \(query)")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"ip": "8.8.8.8", "city": "Mountain View"}"#.data(using: .utf8)!
            return (response, data)
        }

        let info = try await client.lookup("8.8.8.8", fields: ["ip", "city", "country_name"])
        XCTAssertEqual(info.city, "Mountain View")
    }

    func testFieldsParameterPassesNewFieldNamesThrough() async throws {
        // The client does not validate field names; the new ones are sent as given.
        MockURLProtocol.requestHandler = { request in
            let query = request.url!.query!
            XCTAssertTrue(query.contains("fields=is_satellite,is_anycast,is_eu"), "Query: \(query)")
            return okResponse(for: request, json: #"{"is_anycast": true, "is_eu": false}"#)
        }

        let info = try await client.lookup("8.8.8.8", fields: ["is_satellite", "is_anycast", "is_eu"])
        XCTAssertTrue(info.isAnycast)
        XCTAssertFalse(info.isSatellite)
        XCTAssertEqual(info.isEU, false)
    }

    func testLookupFieldReturnsRawData() async throws {
        let asnJSON = #"{"asn": "AS15169", "name": "Google LLC"}"#
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/8.8.8.8/asn"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, asnJSON.data(using: .utf8)!)
        }

        let data = try await client.lookupField("8.8.8.8", field: "asn")
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, asnJSON)
    }

    // MARK: - EU Endpoint

    func testEUEndpointUsesCorrectBaseURL() async throws {
        let euClient = IPDataClient(apiKey: "test-api-key", baseURL: IPDataClient.euBaseURL, session: session)

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("eu-api.ipdata.co"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"ip": "8.8.8.8"}"#.data(using: .utf8)!
            return (response, data)
        }

        let info = try await euClient.lookup("8.8.8.8")
        XCTAssertEqual(info.ip, "8.8.8.8")
    }

    // MARK: - Bulk Lookup

    func testBulkLookupSendsPostWithIPsInBody() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.path.contains("/bulk"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "test-api-key")

            guard let bodyData = requestBody(of: request) else {
                XCTFail("Expected an HTTP body on the bulk request")
                throw URLError(.unknown)
            }
            let body = try JSONDecoder().decode([String].self, from: bodyData)
            XCTAssertEqual(body, ["1.1.1.1", "8.8.8.8"])

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"[{"ip": "1.1.1.1"}, {"ip": "8.8.8.8"}]"#.data(using: .utf8)!
            return (response, data)
        }

        let results = try await client.bulkLookup(["1.1.1.1", "8.8.8.8"])
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].ip, "1.1.1.1")
        XCTAssertEqual(results[1].ip, "8.8.8.8")
    }

    func testBulkLookupSendsTheAPIKeyOnceAsAQueryItem() async throws {
        MockURLProtocol.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let items = components.queryItems ?? []
            let apiKeyItems = items.filter { $0.name == "api-key" }
            XCTAssertEqual(apiKeyItems.count, 1, "Query: \(components.query ?? "")")
            XCTAssertEqual(apiKeyItems.first?.value, "test-api-key")
            XCTAssertTrue(items.contains(where: { $0.name == "fields" && $0.value == "ip" }))
            return okResponse(for: request, json: #"[{"ip": "1.1.1.1"}]"#)
        }

        _ = try await client.bulkLookup(["1.1.1.1"], fields: ["ip"])
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    // MARK: - Connection Reuse

    func testConsecutiveRequestsGoThroughTheSameInjectedSession() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST" {
                return okResponse(for: request, json: #"[{"ip": "1.1.1.1"}, {"ip": "8.8.8.8"}]"#)
            }
            return okResponse(for: request, json: #"{"ip": "8.8.8.8"}"#)
        }

        // MockURLProtocol is registered only on the session injected into `client`, so a
        // request that reaches it necessarily went through that session rather than
        // through URLSession.shared or a transport created per request.
        _ = try await client.lookup("8.8.8.8")
        _ = try await client.lookup("8.8.8.8", fields: ["ip"])
        _ = try await client.lookup()
        _ = try await client.lookupField("8.8.8.8", field: "asn")
        _ = try await client.bulkLookup(["1.1.1.1", "8.8.8.8"])
        _ = try await client.lookupASN("AS15169")

        XCTAssertEqual(MockURLProtocol.requestCount, 6)
    }

    func testOwnedSessionInitialiserSendsRequestsThroughItsConfiguration() async throws {
        let owned = IPDataClient(apiKey: "test-api-key", configuration: mockConfiguration())
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return okResponse(for: request, json: #"{"ip": "8.8.8.8"}"#)
        }

        let first = try await owned.lookup("8.8.8.8")
        let second = try await owned.lookup("8.8.8.8")

        XCTAssertEqual(first.ip, "8.8.8.8")
        XCTAssertEqual(second.ip, "8.8.8.8")
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testOwnedSessionInitialiserAcceptsBaseURL() async throws {
        let owned = IPDataClient(
            apiKey: "test-api-key",
            baseURL: IPDataClient.euBaseURL,
            configuration: mockConfiguration()
        )
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("eu-api.ipdata.co"))
            return okResponse(for: request, json: #"{"ip": "8.8.8.8"}"#)
        }

        let info = try await owned.lookup("8.8.8.8")
        XCTAssertEqual(info.ip, "8.8.8.8")
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testClientWithOwnedSessionIsReleasedAfterUse() async throws {
        MockURLProtocol.requestHandler = { request in
            okResponse(for: request, json: #"{"ip": "8.8.8.8"}"#)
        }
        var owned: IPDataClient? = IPDataClient(apiKey: "test-api-key", configuration: mockConfiguration())
        weak var weakClient = owned

        _ = try await owned?.lookup("8.8.8.8")
        owned = nil

        // The owned session does not retain the client, so `deinit` (which invalidates
        // that session) runs as soon as the last reference to the client goes away.
        XCTAssertNil(weakClient)
    }

    // MARK: - Bulk Retry

    func testBulkLookupRetriesOnceWhenTheConnectionWasLost() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            if MockURLProtocol.requestCount == 1 {
                // A pooled connection the server closed while idle: no response bytes arrived.
                throw URLError(.networkConnectionLost)
            }
            return okResponse(for: request, json: #"[{"ip": "1.1.1.1"}]"#)
        }

        let results = try await client.bulkLookup(["1.1.1.1"])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].ip, "1.1.1.1")
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "the bulk request should be sent exactly twice")
    }

    func testBulkLookupIsRetriedOnlyOnce() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }

        do {
            _ = try await client.bulkLookup(["1.1.1.1"])
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .networkError(let underlying) = error else {
                return XCTFail("Expected .networkError, got \(error)")
            }
            XCTAssertEqual((underlying as? URLError)?.code, .networkConnectionLost)
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "one retry, then the error surfaces")
    }

    func testBulkLookupDoesNotRetryOtherNetworkErrors() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.bulkLookup(["1.1.1.1"])
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .networkError(let underlying) = error else {
                return XCTFail("Expected .networkError, got \(error)")
            }
            XCTAssertEqual((underlying as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testBulkLookupDoesNotRetryOnHTTPStatus() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "Internal server error"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.bulkLookup(["1.1.1.1"])
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .unexpectedStatus(let code, _) = error else {
                return XCTFail("Expected .unexpectedStatus, got \(error)")
            }
            XCTAssertEqual(code, 500)
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testLookupIsNotRetriedByTheClientWhenTheConnectionWasLost() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }

        do {
            _ = try await client.lookup("8.8.8.8")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .networkError = error else {
                return XCTFail("Expected .networkError, got \(error)")
            }
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    // MARK: - ASN Lookup

    func testASNLookupPrependsASPrefix() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/AS15169"), "Path: \(request.url!.path)")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"asn": "AS15169", "name": "Google LLC"}"#.data(using: .utf8)!
            return (response, data)
        }

        let detail = try await client.lookupASN("15169")
        XCTAssertEqual(detail.asn, "AS15169")
    }

    func testASNLookupKeepsExistingPrefix() async throws {
        MockURLProtocol.requestHandler = { request in
            // Should NOT double-prefix to "ASAS15169"
            XCTAssertTrue(request.url!.path.contains("/AS15169"), "Path: \(request.url!.path)")
            XCTAssertFalse(request.url!.path.contains("ASAS"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"asn": "AS15169", "name": "Google LLC"}"#.data(using: .utf8)!
            return (response, data)
        }

        let detail = try await client.lookupASN("AS15169")
        XCTAssertEqual(detail.name, "Google LLC")
    }

    // MARK: - Error Mapping

    func testBadRequestError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "1.2.3.4.5 does not appear to be an IPv4 or IPv6 address"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("1.2.3.4.5")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .badRequest(let msg) = error else {
                return XCTFail("Expected .badRequest, got \(error)")
            }
            XCTAssertTrue(msg.contains("does not appear to be"))
        }
    }

    func testUnauthorizedError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "You have not provided a valid API Key."}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("8.8.8.8")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .unauthorized(let msg) = error else {
                return XCTFail("Expected .unauthorized, got \(error)")
            }
            XCTAssertTrue(msg.contains("valid API Key"))
        }
    }

    func testForbiddenError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "You have exceeded your daily quota."}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("8.8.8.8")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .forbidden(let msg) = error else {
                return XCTFail("Expected .forbidden, got \(error)")
            }
            XCTAssertTrue(msg.contains("quota"))
        }
    }

    func testNotFoundError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "Not found"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookupASN("AS99999999")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .notFound = error else {
                return XCTFail("Expected .notFound, got \(error)")
            }
        }
    }

    func testUnexpectedStatusError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "Internal server error"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("8.8.8.8")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .unexpectedStatus(let code, let msg) = error else {
                return XCTFail("Expected .unexpectedStatus, got \(error)")
            }
            XCTAssertEqual(code, 500)
            XCTAssertTrue(msg.contains("Internal server error"))
        }
    }

    func testErrorFallsBackToRawBody() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            let data = "plain text error".data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("bad")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .badRequest(let msg) = error else {
                return XCTFail("Expected .badRequest, got \(error)")
            }
            XCTAssertEqual(msg, "plain text error")
        }
    }

    func testDecodingError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "not json at all".data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.lookup("8.8.8.8")
            XCTFail("Expected error")
        } catch let error as IPDataError {
            guard case .decodingFailed = error else {
                return XCTFail("Expected .decodingFailed, got \(error)")
            }
        }
    }
}
