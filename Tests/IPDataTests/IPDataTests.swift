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
        XCTAssertFalse(info.isSatellite)
        XCTAssertFalse(info.isAnycast)
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
        XCTAssertFalse(info.isSatellite)
        XCTAssertFalse(info.isAnycast)
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
        XCTAssertNil(threat.blocklists?.first?.firstSeen)
        XCTAssertNil(threat.blocklists?.first?.lastSeen)
        XCTAssertNil(threat.blocklists?.first?.daysSeen)
        XCTAssertEqual(threat.scores?.proxyScore, 85)
        XCTAssertEqual(threat.scores?.threatScore, 92)
    }

    // MARK: - is_satellite, is_anycast and Blocklist Dates

    func testDecodeSatelliteResponse() throws {
        // Sample A: a satellite ISP. The API sends `is_satellite` only when it is true.
        let json = """
        {
            "ip": "98.97.34.0",
            "is_satellite": true,
            "is_eu": false,
            "city": "Seattle",
            "country_code": "US",
            "asn": {
                "asn": "AS14593",
                "name": "Space Exploration Technologies Corporation",
                "domain": "spacex.com",
                "route": "98.97.32.0/21",
                "type": "business"
            },
            "threat": {
                "is_tor": false,
                "is_vpn": false,
                "is_icloud_relay": false,
                "is_proxy": false,
                "is_datacenter": false,
                "is_anonymous": false,
                "is_known_attacker": false,
                "is_known_abuser": false,
                "is_threat": false,
                "is_bogon": false,
                "blocklists": [],
                "scores": {"vpn_score": 0, "proxy_score": 1, "threat_score": 8, "trust_score": 97}
            },
            "count": "0"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.ip, "98.97.34.0")
        XCTAssertTrue(info.isSatellite)
        XCTAssertFalse(info.isAnycast, "is_anycast is absent, so it reads false")
        XCTAssertEqual(info.isEU, false)
        XCTAssertEqual(info.city, "Seattle")
        XCTAssertEqual(info.countryCode, "US")
        XCTAssertEqual(info.asn?.asn, "AS14593")
        XCTAssertEqual(info.asn?.name, "Space Exploration Technologies Corporation")
        XCTAssertEqual(info.threat?.isDatacenter, false)
        XCTAssertEqual(info.threat?.blocklists?.isEmpty, true)
        XCTAssertEqual(info.threat?.scores?.trustScore, 97)
        XCTAssertEqual(info.count, 0)
    }

    func testDecodeAnycastResponseWithDatedBlocklists() throws {
        // Sample B: an anycast address with dated blocklist entries (complete response).
        let json = """
        {
            "ip": "8.8.8.8",
            "is_anycast": true,
            "is_eu": false,
            "city": null,
            "region": null,
            "region_code": null,
            "region_type": null,
            "country_name": "United States",
            "country_code": "US",
            "continent_name": "North America",
            "continent_code": "NA",
            "latitude": 39.7599983215332,
            "longitude": -98.5,
            "postal": null,
            "calling_code": "1",
            "flag": "https://ipdata.co/flags/us.png",
            "emoji_flag": "🇺🇸",
            "emoji_unicode": "U+1F1FA U+1F1F8",
            "asn": {"asn": "AS15169", "name": "Google LLC", "domain": "about.google", "route": "8.8.8.0/24", "type": "hosting"},
            "company": {"name": "Google LLC", "domain": "about.google", "network": "8.8.8.0/24", "type": "hosting"},
            "languages": [{"name": "English", "native": "English", "code": "en"}],
            "currency": {"name": "US Dollar", "code": "USD", "symbol": "$", "native": "$", "plural": "US dollars"},
            "time_zone": {"name": null, "abbr": null, "offset": null, "is_dst": null, "current_time": null},
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
                "blocklists": [
                    {"days_seen": 1, "first_seen": "2026-11-02", "last_seen": "2026-11-02", "name": "ipdata", "site": "https://ipdata.co", "type": "cloud"},
                    {"days_seen": 1, "first_seen": "2026-11-02", "last_seen": "2026-11-02", "name": "ipdata", "site": "https://ipdata.co", "type": "open_resolvers"}
                ],
                "scores": {"vpn_score": 100, "proxy_score": 93, "threat_score": 100, "trust_score": 2}
            },
            "count": "0"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.ip, "8.8.8.8")
        XCTAssertTrue(info.isAnycast)
        XCTAssertFalse(info.isSatellite, "is_satellite is absent, so it reads false")
        XCTAssertEqual(info.isEU, false)
        XCTAssertNil(info.city)
        XCTAssertEqual(info.countryName, "United States")
        XCTAssertEqual(info.latitude, 39.7599983215332)
        XCTAssertNil(info.timeZone?.name)
        XCTAssertEqual(info.threat?.isDatacenter, true)

        let blocklists = try XCTUnwrap(info.threat?.blocklists)
        XCTAssertEqual(blocklists.count, 2)
        XCTAssertEqual(blocklists[0].name, "ipdata")
        XCTAssertEqual(blocklists[0].site, "https://ipdata.co")
        XCTAssertEqual(blocklists[0].type, "cloud")
        XCTAssertEqual(blocklists[0].firstSeen, "2026-11-02")
        XCTAssertEqual(blocklists[0].lastSeen, "2026-11-02")
        XCTAssertEqual(blocklists[0].daysSeen, 1)
        XCTAssertEqual(blocklists[1].type, "open_resolvers")
        XCTAssertEqual(blocklists[1].daysSeen, 1)
        XCTAssertEqual(info.threat?.scores?.trustScore, 2)
        XCTAssertEqual(info.count, 0)
    }

    func testDecodeBlocklistEntryWithoutDates() throws {
        // Sample C: a VPN exit. Neither top-level flag is present, and the third
        // blocklist entry (ipdata's own vpn feed) carries no dates.
        let json = """
        {
            "ip": "187.13.250.1",
            "is_eu": false,
            "threat": {
                "is_tor": false,
                "is_vpn": true,
                "is_icloud_relay": false,
                "is_proxy": false,
                "is_datacenter": true,
                "is_anonymous": true,
                "is_known_attacker": true,
                "is_known_abuser": true,
                "is_threat": true,
                "is_bogon": false,
                "blocklists": [
                    {"days_seen": 2, "first_seen": "2026-10-31", "last_seen": "2026-11-02", "name": "Gluetun", "site": "https://github.com/qdm12/gluetun", "type": "vpn"},
                    {"days_seen": 1, "first_seen": "2026-11-02", "last_seen": "2026-11-02", "name": "ipdata", "site": "https://ipdata.co", "type": "cloud"},
                    {"name": "ipdata", "site": "https://ipdata.co", "type": "vpn"},
                    {"days_seen": 2, "first_seen": "2026-10-31", "last_seen": "2026-11-02", "name": "NordVPN", "site": "https://nordvpn.com", "type": "vpn"},
                    {"days_seen": 2, "first_seen": "2026-10-31", "last_seen": "2026-11-02", "name": "Wikimedia Global Blocklist", "site": "https://wikimedia.org", "type": "general"},
                    {"days_seen": 2, "first_seen": "2026-10-31", "last_seen": "2026-11-02", "name": "X4BNet", "site": "https://github.com/X4BNet/lists_vpn", "type": "vpn"}
                ],
                "scores": {"vpn_score": 100, "proxy_score": 99, "threat_score": 100, "trust_score": 0}
            },
            "count": "0"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.ip, "187.13.250.1")
        XCTAssertFalse(info.isSatellite)
        XCTAssertFalse(info.isAnycast)
        XCTAssertEqual(info.threat?.isVPN, true)
        XCTAssertEqual(info.threat?.isThreat, true)

        let blocklists = try XCTUnwrap(info.threat?.blocklists)
        XCTAssertEqual(blocklists.count, 6)
        XCTAssertEqual(blocklists[0].name, "Gluetun")
        XCTAssertEqual(blocklists[0].firstSeen, "2026-10-31")
        XCTAssertEqual(blocklists[0].lastSeen, "2026-11-02")
        XCTAssertEqual(blocklists[0].daysSeen, 2)

        // The vpn feed entry has no first_seen, last_seen or days_seen; decoding still succeeds.
        XCTAssertEqual(blocklists[2].name, "ipdata")
        XCTAssertEqual(blocklists[2].site, "https://ipdata.co")
        XCTAssertEqual(blocklists[2].type, "vpn")
        XCTAssertNil(blocklists[2].firstSeen)
        XCTAssertNil(blocklists[2].lastSeen)
        XCTAssertNil(blocklists[2].daysSeen)

        XCTAssertEqual(blocklists[5].name, "X4BNet")
        XCTAssertEqual(blocklists[5].daysSeen, 2)
        XCTAssertEqual(info.threat?.scores?.trustScore, 0)
    }

    func testNewFlagsReadFalseUnlessSentAsTrue() throws {
        let absent = try JSONDecoder().decode(
            IPResponse.self,
            from: #"{"ip": "1.1.1.1", "is_eu": true}"#.data(using: .utf8)!
        )
        XCTAssertFalse(absent.isSatellite)
        XCTAssertFalse(absent.isAnycast)
        XCTAssertEqual(absent.isEU, true)

        let explicit = try JSONDecoder().decode(
            IPResponse.self,
            from: #"{"ip": "1.1.1.1", "is_satellite": false, "is_anycast": true}"#.data(using: .utf8)!
        )
        XCTAssertFalse(explicit.isSatellite)
        XCTAssertTrue(explicit.isAnycast)

        let nullFlag = try JSONDecoder().decode(
            IPResponse.self,
            from: #"{"ip": "1.1.1.1", "is_satellite": null}"#.data(using: .utf8)!
        )
        XCTAssertFalse(nullFlag.isSatellite)
    }

    func testDecodeBulkResponseWithNewFields() throws {
        // Bulk responses carry the same shape per item.
        let json = """
        [
            {"ip": "98.97.34.0", "is_satellite": true, "is_eu": false},
            {
                "ip": "8.8.8.8",
                "is_anycast": true,
                "is_eu": false,
                "threat": {
                    "is_vpn": false,
                    "blocklists": [
                        {"days_seen": 1, "first_seen": "2026-11-02", "last_seen": "2026-11-02", "name": "ipdata", "site": "https://ipdata.co", "type": "cloud"}
                    ]
                }
            },
            {
                "ip": "187.13.250.1",
                "is_eu": false,
                "threat": {
                    "is_vpn": true,
                    "blocklists": [{"name": "ipdata", "site": "https://ipdata.co", "type": "vpn"}]
                }
            }
        ]
        """.data(using: .utf8)!

        let results = try JSONDecoder().decode([IPResponse].self, from: json)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].isSatellite)
        XCTAssertFalse(results[0].isAnycast)
        XCTAssertFalse(results[1].isSatellite)
        XCTAssertTrue(results[1].isAnycast)
        XCTAssertEqual(results[1].threat?.blocklists?.first?.firstSeen, "2026-11-02")
        XCTAssertEqual(results[1].threat?.blocklists?.first?.lastSeen, "2026-11-02")
        XCTAssertEqual(results[1].threat?.blocklists?.first?.daysSeen, 1)
        XCTAssertFalse(results[2].isSatellite)
        XCTAssertFalse(results[2].isAnycast)
        XCTAssertEqual(results[2].threat?.isVPN, true)
        XCTAssertNil(results[2].threat?.blocklists?.first?.firstSeen)
        XCTAssertNil(results[2].threat?.blocklists?.first?.lastSeen)
        XCTAssertNil(results[2].threat?.blocklists?.first?.daysSeen)
    }

    func testDecoderIgnoresUnknownKeys() throws {
        let json = """
        {
            "ip": "8.8.8.8",
            "is_anycast": true,
            "some_future_field": {"nested": [1, 2, 3]},
            "threat": {
                "is_vpn": false,
                "another_future_field": true,
                "blocklists": [{"name": "ipdata", "type": "cloud", "yet_another_field": "x"}]
            }
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(IPResponse.self, from: json)
        XCTAssertEqual(info.ip, "8.8.8.8")
        XCTAssertTrue(info.isAnycast)
        XCTAssertEqual(info.threat?.isVPN, false)
        XCTAssertEqual(info.threat?.blocklists?.first?.name, "ipdata")
        XCTAssertNil(info.threat?.blocklists?.first?.daysSeen)
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
