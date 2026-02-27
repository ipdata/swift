# IPData Swift SDK

A lightweight Swift client for the [ipdata.co](https://ipdata.co) IP Geolocation & Threat Intelligence API. Built on Foundation with no third-party dependencies.

## Requirements

- Swift 5.9+
- macOS 12+ / iOS 15+ / tvOS 15+ / watchOS 8+ / Linux

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ipdata/swift.git", from: "1.0.0")
]
```

Then add `"IPData"` to your target:

```swift
.target(name: "MyApp", dependencies: ["IPData"])
```

In Xcode, go to **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import IPData

let client = IPDataClient(apiKey: "YOUR_API_KEY")

// Look up an IP address
let info = try await client.lookup("8.8.8.8")
print(info.city ?? "")          // Mountain View
print(info.countryName ?? "")   // United States
print(info.threat?.isVPN ?? false)
```

## Usage

### Look Up the Current Device's IP

```swift
let info = try await client.lookup()
print(info.ip ?? "unknown")
```

### Look Up a Specific IP

```swift
let info = try await client.lookup("1.1.1.1")
print(info.countryCode ?? "")  // AU
print(info.asn?.name ?? "")    // Cloudflare, Inc.
```

### Select Specific Fields

Reduce response size by requesting only the fields you need:

```swift
let info = try await client.lookup("8.8.8.8", fields: ["ip", "city", "country_name"])
```

### Look Up a Single Field

Returns raw `Data` for a single field:

```swift
let data = try await client.lookupField("8.8.8.8", field: "asn")
```

### Bulk Lookup (up to 100 IPs)

```swift
let results = try await client.bulkLookup(["1.1.1.1", "8.8.8.8"])
for info in results {
    print("\(info.ip ?? ""): \(info.countryName ?? "")")
}
```

### ASN Lookup

```swift
let detail = try await client.lookupASN("AS15169")
print(detail.name ?? "")               // Google LLC
print(detail.numIPs ?? "")             // 16777216
print(detail.ipv4Prefixes ?? [])
print(detail.peers ?? [])
```

### Threat Intelligence

```swift
let info = try await client.lookup("1.2.3.4")
if let threat = info.threat {
    print("Tor: \(threat.isTor ?? false)")
    print("VPN: \(threat.isVPN ?? false)")
    print("Proxy: \(threat.isProxy ?? false)")
    print("Threat score: \(threat.scores?.threatScore ?? 0)")
    print("Trust score: \(threat.scores?.trustScore ?? 0)")

    for entry in threat.blocklists ?? [] {
        print("Listed on: \(entry.name ?? "")")
    }
}
```

### EU Endpoint

Route all requests through EU-based servers:

```swift
let client = IPDataClient(apiKey: "YOUR_API_KEY", baseURL: IPDataClient.euBaseURL)
```

## Error Handling

All methods throw `IPDataError`:

```swift
do {
    let info = try await client.lookup("8.8.8.8")
} catch let error as IPDataError {
    switch error {
    case .badRequest(let msg):
        print("Bad request: \(msg)")
    case .unauthorized(let msg):
        print("Invalid API key: \(msg)")
    case .forbidden(let msg):
        print("Forbidden (quota exceeded?): \(msg)")
    case .notFound(let msg):
        print("Not found: \(msg)")
    case .unexpectedStatus(let code, let msg):
        print("HTTP \(code): \(msg)")
    case .decodingFailed(let underlying):
        print("Decoding error: \(underlying)")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    }
}
```

## Response Models

### IPResponse

The primary response type for IP lookups.

| Property | Type | Description |
|---|---|---|
| `ip` | `String?` | IP address |
| `isEU` | `Bool?` | Located in the EU |
| `city` | `String?` | City name |
| `region` | `String?` | Region / state |
| `regionCode` | `String?` | Region code |
| `countryName` | `String?` | Country name |
| `countryCode` | `String?` | ISO 3166-1 alpha-2 code |
| `continentName` | `String?` | Continent name |
| `continentCode` | `String?` | Continent code |
| `latitude` | `Double?` | Latitude |
| `longitude` | `Double?` | Longitude |
| `postal` | `String?` | Postal / ZIP code |
| `callingCode` | `String?` | International calling code |
| `flag` | `String?` | Flag image URL |
| `emojiFlag` | `String?` | Flag emoji |
| `asn` | `ASN?` | Autonomous system info |
| `company` | `Company?` | Organization that owns the IP |
| `carrier` | `Carrier?` | Mobile carrier info |
| `languages` | `[Language]?` | Languages spoken in the country |
| `currency` | `Currency?` | Local currency |
| `timeZone` | `TimeZone?` | Time zone details |
| `threat` | `Threat?` | Threat intelligence data |
| `count` | `Int?` | API requests in last 24 hours |

### ASNDetail

Detailed ASN data from the dedicated `/asn` endpoint. Includes `ipv4Prefixes`, `ipv6Prefixes`, `numIPs`, `upstream`, `downstream`, and `peers`.

### Threat

Threat intelligence flags: `isTor`, `isVPN`, `isICloudRelay`, `isProxy`, `isDatacenter`, `isAnonymous`, `isKnownAttacker`, `isKnownAbuser`, `isThreat`, `isBogon`. Includes `blocklists` and reputation `scores` (0-100 for VPN, proxy, threat, and trust).

All model types conform to `Codable`, `Sendable`, and `Equatable`.
