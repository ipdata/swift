import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import IPData

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
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

// MARK: - Client Tests

final class IPDataClientTests: XCTestCase {

    private var session: URLSession!
    private var client: IPDataClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = IPDataClient(apiKey: "test-api-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
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

    func testLookupFieldReturnsRawData() async throws {
        let asnJSON = #"{"asn": "AS15169", "name": "Google LLC"}"#
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/8.8.8.8/asn"))

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
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "test-api-key")

            let body = try! JSONDecoder().decode([String].self, from: request.httpBody!)
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
