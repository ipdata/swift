import Foundation

// MARK: - IP Lookup Response

/// Complete response from an IP address lookup.
public struct IPResponse: Codable, Sendable, Equatable {
    public let ip: String?
    public let isEU: Bool?
    /// Whether the address belongs to a satellite internet provider.
    ///
    /// The API sends `is_satellite` only when it is true, so this reads `false`
    /// whenever the key is absent from the response.
    public let isSatellite: Bool
    /// Whether the address is anycast, i.e. announced from several locations at once.
    ///
    /// The API sends `is_anycast` only when it is true, so this reads `false`
    /// whenever the key is absent from the response.
    public let isAnycast: Bool
    public let city: String?
    public let region: String?
    public let regionCode: String?
    public let regionType: String?
    public let countryName: String?
    public let countryCode: String?
    public let continentName: String?
    public let continentCode: String?
    public let latitude: Double?
    public let longitude: Double?
    public let postal: String?
    public let callingCode: String?
    public let flag: String?
    public let emojiFlag: String?
    public let emojiUnicode: String?
    public let asn: ASN?
    public let company: Company?
    public let carrier: Carrier?
    public let languages: [Language]?
    public let currency: Currency?
    public let timeZone: TimeZoneInfo?
    public let threat: Threat?
    /// Number of API requests made in the last 24 hours.
    /// The API may return this as either a number or a string.
    public let count: Int?

    enum CodingKeys: String, CodingKey {
        case ip
        case isEU = "is_eu"
        case isSatellite = "is_satellite"
        case isAnycast = "is_anycast"
        case city, region
        case regionCode = "region_code"
        case regionType = "region_type"
        case countryName = "country_name"
        case countryCode = "country_code"
        case continentName = "continent_name"
        case continentCode = "continent_code"
        case latitude, longitude, postal
        case callingCode = "calling_code"
        case flag
        case emojiFlag = "emoji_flag"
        case emojiUnicode = "emoji_unicode"
        case asn, company, carrier, languages, currency
        case timeZone = "time_zone"
        case threat, count
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ip = try c.decodeIfPresent(String.self, forKey: .ip)
        isEU = try c.decodeIfPresent(Bool.self, forKey: .isEU)
        // The API includes these two keys only when they are true.
        isSatellite = try c.decodeIfPresent(Bool.self, forKey: .isSatellite) ?? false
        isAnycast = try c.decodeIfPresent(Bool.self, forKey: .isAnycast) ?? false
        city = try c.decodeIfPresent(String.self, forKey: .city)
        region = try c.decodeIfPresent(String.self, forKey: .region)
        regionCode = try c.decodeIfPresent(String.self, forKey: .regionCode)
        regionType = try c.decodeIfPresent(String.self, forKey: .regionType)
        countryName = try c.decodeIfPresent(String.self, forKey: .countryName)
        countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode)
        continentName = try c.decodeIfPresent(String.self, forKey: .continentName)
        continentCode = try c.decodeIfPresent(String.self, forKey: .continentCode)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        postal = try c.decodeIfPresent(String.self, forKey: .postal)
        callingCode = try c.decodeIfPresent(String.self, forKey: .callingCode)
        flag = try c.decodeIfPresent(String.self, forKey: .flag)
        emojiFlag = try c.decodeIfPresent(String.self, forKey: .emojiFlag)
        emojiUnicode = try c.decodeIfPresent(String.self, forKey: .emojiUnicode)
        asn = try c.decodeIfPresent(ASN.self, forKey: .asn)
        company = try c.decodeIfPresent(Company.self, forKey: .company)
        carrier = try c.decodeIfPresent(Carrier.self, forKey: .carrier)
        languages = try c.decodeIfPresent([Language].self, forKey: .languages)
        currency = try c.decodeIfPresent(Currency.self, forKey: .currency)
        timeZone = try c.decodeIfPresent(TimeZoneInfo.self, forKey: .timeZone)
        threat = try c.decodeIfPresent(Threat.self, forKey: .threat)
        // The API returns count as either an Int or a String.
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .count) {
            count = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .count) {
            count = Int(strVal)
        } else {
            count = nil
        }
    }
}

// MARK: - ASN (Basic)

/// Autonomous System Number data returned with IP lookups.
public struct ASN: Codable, Sendable, Equatable {
    public let asn: String?
    public let name: String?
    public let domain: String?
    public let route: String?
    public let type: String?
}

// MARK: - Advanced ASN

/// Detailed ASN data returned by the dedicated ASN endpoint.
public struct ASNDetail: Codable, Sendable, Equatable {
    public let asn: String?
    public let name: String?
    public let domain: String?
    public let usage: String?
    public let ipv4Prefixes: [String]?
    public let ipv6Prefixes: [String]?
    public let numIPs: String?
    public let registry: String?
    public let country: String?
    public let date: String?
    public let status: String?
    public let upstream: [Int]?
    public let downstream: [Int]?
    public let peers: [Int]?

    enum CodingKeys: String, CodingKey {
        case asn, name, domain, usage
        case ipv4Prefixes = "ipv4_prefixes"
        case ipv6Prefixes = "ipv6_prefixes"
        case numIPs = "num_ips"
        case registry, country, date, status
        case upstream, downstream, peers
    }
}

// MARK: - Company

/// Organization that owns the IP address.
public struct Company: Codable, Sendable, Equatable {
    public let name: String?
    public let domain: String?
    public let network: String?
    public let type: String?
}

// MARK: - Carrier

/// Mobile carrier information for mobile IP addresses.
public struct Carrier: Codable, Sendable, Equatable {
    public let name: String?
    public let mcc: String?
    public let mnc: String?
}

// MARK: - Language

/// Language spoken in the country of the IP address.
public struct Language: Codable, Sendable, Equatable {
    public let name: String?
    public let native: String?
    public let code: String?
}

// MARK: - Currency

/// Currency used in the country of the IP address.
public struct Currency: Codable, Sendable, Equatable {
    public let name: String?
    public let code: String?
    public let symbol: String?
    public let native: String?
    public let plural: String?
}

// MARK: - TimeZone

/// Time zone information for the IP address location.
public struct TimeZoneInfo: Codable, Sendable, Equatable {
    public let name: String?
    public let abbr: String?
    public let offset: String?
    public let isDST: Bool?
    public let currentTime: String?

    enum CodingKeys: String, CodingKey {
        case name, abbr, offset
        case isDST = "is_dst"
        case currentTime = "current_time"
    }
}

// MARK: - Threat

/// Threat intelligence data for the IP address.
public struct Threat: Codable, Sendable, Equatable {
    public let isTor: Bool?
    public let isVPN: Bool?
    public let isICloudRelay: Bool?
    public let isProxy: Bool?
    public let isDatacenter: Bool?
    public let isAnonymous: Bool?
    public let isKnownAttacker: Bool?
    public let isKnownAbuser: Bool?
    public let isThreat: Bool?
    public let isBogon: Bool?
    public let blocklists: [Blocklist]?
    public let scores: ThreatScores?

    enum CodingKeys: String, CodingKey {
        case isTor = "is_tor"
        case isVPN = "is_vpn"
        case isICloudRelay = "is_icloud_relay"
        case isProxy = "is_proxy"
        case isDatacenter = "is_datacenter"
        case isAnonymous = "is_anonymous"
        case isKnownAttacker = "is_known_attacker"
        case isKnownAbuser = "is_known_abuser"
        case isThreat = "is_threat"
        case isBogon = "is_bogon"
        case blocklists, scores
    }
}

// MARK: - Blocklist

/// A blocklist entry that an IP address appears on.
///
/// `firstSeen`, `lastSeen` and `daysSeen` are omitted by some feeds (for example
/// ipdata's own VPN feed), so they are optional. The dates are kept as the
/// `YYYY-MM-DD` (UTC) strings the API sends.
public struct Blocklist: Codable, Sendable, Equatable {
    public let name: String?
    public let site: String?
    public let type: String?
    /// First day the address was seen on this list, as `YYYY-MM-DD` (UTC).
    public let firstSeen: String?
    /// Last day the address was seen on this list, as `YYYY-MM-DD` (UTC).
    public let lastSeen: String?
    /// Number of days the address has been seen on this list.
    public let daysSeen: Int?

    enum CodingKeys: String, CodingKey {
        case name, site, type
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
        case daysSeen = "days_seen"
    }
}

// MARK: - ThreatScores

/// IP reputation scores (0–100).
public struct ThreatScores: Codable, Sendable, Equatable {
    public let vpnScore: Int?
    public let proxyScore: Int?
    public let threatScore: Int?
    public let trustScore: Int?

    enum CodingKeys: String, CodingKey {
        case vpnScore = "vpn_score"
        case proxyScore = "proxy_score"
        case threatScore = "threat_score"
        case trustScore = "trust_score"
    }
}
