import XCTest
@testable import IPData

final class IPDataTests: XCTestCase {

    // MARK: - Model Decoding

    func testDecodeFullIPResponse() throws {
        let json = """
        {
            "ip": "8.8.8.8",
            "is_eu": false,
            "city": "Mountain View",
            "region": "California",
            "region_code": "CA",
            "region_type": "state",
            "country_name": "United States",
            "country_code": "US",
            "continent_name": "North America",
            "continent_code": "NA",
            "latitude": 37.386,
            "longitude": -122.0838,
            "postal": "94035",
            "calling_code": "1",
            "flag": "https://ipdata.co/flags/us.png",
            "emoji_flag": "🇺🇸",
            "emoji_unicode": "U+1F1FA U+1F1F8",
            "asn": {
                "asn": "AS15169",
                "name": "Google LLC",
                "domain": "google.com",
                "route": "8.8.8.0/24",
                "type": "hosting"
            },
            "company": {
                "name": "Google LLC",
                "domain": "google.com",
                "network": "8.8.8.0/24",
                "type": "hosting"
            },
            "carrier": {
                "name": "Google",
                "mcc": "310",
                "mnc": "004"
            },
            "languages": [
                {"name": "English", "native": "English", "code": "en"}
            ],
            "currency": {
                "name": "US Dollar",
                "code": "USD",
                "symbol": "$",
                "native": "$",
                "plural": "US dollars"
            },
            "time_zone": {
                "name": "America/Los_Angeles",
                "abbr": "PDT",
                "offset": "-0700",
                "is_dst": true,
                "current_time": "2025-06-15T10:30:00-07:00"
            },
            "threat": {
                "is_tor": false,
                "is_vpn": false,
                "is_icloud_relay": false,
                "is_proxy": false,
                "is_datacenter": true,
                "is_anonymous": false,
                "is_known_attacker": false,
                "is_known_abuser": false,
                "is_threat": false,
                "is_bogon": false,
                "blocklists": [],
                "scores": {
                    "vpn_score": 0,
                    "proxy_score": 0,
                    "threat_score": 5,
                    "trust_score": 95
                }
            },
            "count": 42
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)

        XCTAssertEqual(info.ip, "8.8.8.8")
        XCTAssertEqual(info.isEU, false)
        XCTAssertEqual(info.city, "Mountain View")
        XCTAssertEqual(info.region, "California")
        XCTAssertEqual(info.regionCode, "CA")
        XCTAssertEqual(info.regionType, "state")
        XCTAssertEqual(info.countryName, "United States")
        XCTAssertEqual(info.countryCode, "US")
        XCTAssertEqual(info.continentName, "North America")
        XCTAssertEqual(info.continentCode, "NA")
        XCTAssertEqual(info.latitude, 37.386)
        XCTAssertEqual(info.longitude, -122.0838)
        XCTAssertEqual(info.postal, "94035")
        XCTAssertEqual(info.callingCode, "1")
        XCTAssertEqual(info.emojiFlag, "🇺🇸")

        // ASN
        XCTAssertEqual(info.asn?.asn, "AS15169")
        XCTAssertEqual(info.asn?.name, "Google LLC")
        XCTAssertEqual(info.asn?.domain, "google.com")
        XCTAssertEqual(info.asn?.route, "8.8.8.0/24")
        XCTAssertEqual(info.asn?.type, "hosting")

        // Company
        XCTAssertEqual(info.company?.name, "Google LLC")
        XCTAssertEqual(info.company?.domain, "google.com")
        XCTAssertEqual(info.company?.network, "8.8.8.0/24")
        XCTAssertEqual(info.company?.type, "hosting")

        // Carrier
        XCTAssertEqual(info.carrier?.name, "Google")
        XCTAssertEqual(info.carrier?.mcc, "310")
        XCTAssertEqual(info.carrier?.mnc, "004")

        // Languages
        XCTAssertEqual(info.languages?.count, 1)
        XCTAssertEqual(info.languages?.first?.name, "English")
        XCTAssertEqual(info.languages?.first?.code, "en")

        // Currency
        XCTAssertEqual(info.currency?.code, "USD")
        XCTAssertEqual(info.currency?.symbol, "$")
        XCTAssertEqual(info.currency?.plural, "US dollars")

        // TimeZone
        XCTAssertEqual(info.timeZone?.name, "America/Los_Angeles")
        XCTAssertEqual(info.timeZone?.abbr, "PDT")
        XCTAssertEqual(info.timeZone?.offset, "-0700")
        XCTAssertEqual(info.timeZone?.isDST, true)

        // Threat
        XCTAssertEqual(info.threat?.isTor, false)
        XCTAssertEqual(info.threat?.isVPN, false)
        XCTAssertEqual(info.threat?.isICloudRelay, false)
        XCTAssertEqual(info.threat?.isProxy, false)
        XCTAssertEqual(info.threat?.isDatacenter, true)
        XCTAssertEqual(info.threat?.isAnonymous, false)
        XCTAssertEqual(info.threat?.isKnownAttacker, false)
        XCTAssertEqual(info.threat?.isKnownAbuser, false)
        XCTAssertEqual(info.threat?.isThreat, false)
        XCTAssertEqual(info.threat?.isBogon, false)
        XCTAssertEqual(info.threat?.blocklists?.isEmpty, true)
        XCTAssertEqual(info.threat?.scores?.threatScore, 5)
        XCTAssertEqual(info.threat?.scores?.trustScore, 95)

        XCTAssertEqual(info.count, 42)
    }

    func testDecodeCountAsString() throws {
        let json = """
        {"ip": "1.1.1.1", "count": "1523"}
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.count, 1523)
    }

    func testDecodePartialIPResponse() throws {
        let json = """
        {"ip": "1.2.3.4", "country_name": "Australia"}
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.ip, "1.2.3.4")
        XCTAssertEqual(info.countryName, "Australia")
        XCTAssertNil(info.city)
        XCTAssertNil(info.asn)
        XCTAssertNil(info.threat)
    }

    func testDecodeASNDetail() throws {
        let json = """
        {
            "asn": "AS15169",
            "name": "Google LLC",
            "domain": "google.com",
            "usage": "hosting",
            "ipv4_prefixes": ["8.8.8.0/24", "8.8.4.0/24"],
            "ipv6_prefixes": ["2001:4860::/32"],
            "num_ips": "16777216",
            "registry": "arin",
            "country": "US",
            "date": "2000-03-30",
            "status": "allocated",
            "upstream": [11537],
            "downstream": [36040],
            "peers": [13335, 20940]
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(ASNDetail.self, from: json)
        XCTAssertEqual(detail.asn, "AS15169")
        XCTAssertEqual(detail.name, "Google LLC")
        XCTAssertEqual(detail.usage, "hosting")
        XCTAssertEqual(detail.ipv4Prefixes?.count, 2)
        XCTAssertEqual(detail.ipv6Prefixes?.first, "2001:4860::/32")
        XCTAssertEqual(detail.numIPs, "16777216")
        XCTAssertEqual(detail.registry, "arin")
        XCTAssertEqual(detail.country, "US")
        XCTAssertEqual(detail.upstream, [11537])
        XCTAssertEqual(detail.downstream, [36040])
        XCTAssertEqual(detail.peers, [13335, 20940])
    }

    func testDecodeBulkResponse() throws {
        let json = """
        [
            {"ip": "1.1.1.1", "country_name": "Australia"},
            {"ip": "8.8.8.8", "country_name": "United States"}
        ]
        """.data(using: .utf8)!

        let results = try JSONDecoder().decode([IPResponse].self, from: json)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].ip, "1.1.1.1")
        XCTAssertEqual(results[1].countryName, "United States")
    }

    func testDecodeThreatWithBlocklists() throws {
        let json = """
        {
            "is_tor": true,
            "is_vpn": false,
            "is_icloud_relay": false,
            "is_proxy": true,
            "is_datacenter": false,
            "is_anonymous": true,
            "is_known_attacker": true,
            "is_known_abuser": true,
            "is_threat": true,
            "is_bogon": false,
            "blocklists": [
                {"name": "Firehol Level 1", "site": "https://firehol.org", "type": "general"},
                {"name": "Emerging Threats", "site": "https://rules.emergingthreats.net", "type": "attacks"}
            ],
            "scores": {
                "vpn_score": 10,
                "proxy_score": 85,
                "threat_score": 92,
                "trust_score": 8
            }
        }
        """.data(using: .utf8)!

        let threat = try JSONDecoder().decode(Threat.self, from: json)
        XCTAssertEqual(threat.isTor, true)
        XCTAssertEqual(threat.isProxy, true)
        XCTAssertEqual(threat.isAnonymous, true)
        XCTAssertEqual(threat.isThreat, true)
        XCTAssertEqual(threat.blocklists?.count, 2)
        XCTAssertEqual(threat.blocklists?.first?.name, "Firehol Level 1")
        XCTAssertEqual(threat.scores?.proxyScore, 85)
        XCTAssertEqual(threat.scores?.threatScore, 92)
    }

    // MARK: - Error Handling

    func testErrorDescriptions() {
        let errors: [(IPDataError, String)] = [
            (.badRequest("Invalid IP"), "Bad Request: Invalid IP"),
            (.unauthorized("No key"), "Unauthorized: No key"),
            (.forbidden("Quota exceeded"), "Forbidden: Quota exceeded"),
            (.notFound("Not found"), "Not Found: Not found"),
            (.unexpectedStatus(statusCode: 500, message: "Server error"), "HTTP 500: Server error"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.description, expected)
        }
    }

    // MARK: - Client Initialization

    func testDefaultBaseURL() {
        let client = IPDataClient(apiKey: "test-key")
        XCTAssertNotNil(client)
    }

    func testEUBaseURL() {
        let client = IPDataClient(apiKey: "test-key", baseURL: IPDataClient.euBaseURL)
        XCTAssertNotNil(client)
    }
}
