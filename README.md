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
    .package(url: "https://github.com/ipdata/swift.git", from: "1.0.2")
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

## Connection reuse and HTTP/2

An `IPDataClient` keeps a persistent HTTPS connection pool for as long as it lives. Create one client per process (or one per API key or endpoint), keep it, and reuse it for every lookup. HTTP/2 and keep-alive are automatic: `URLSession` negotiates HTTP/2 with api.ipdata.co when the platform supports it (Apple platforms, and Linux when libcurl was built with HTTP/2), multiplexes requests over one connection, and falls back to HTTP/1.1 keep-alive otherwise. Only the first request pays the TCP and TLS handshake; nothing needs to be configured.

By default the client sends its requests through `URLSession.shared`, the process-wide session, so its connections are shared with the rest of your app and survive the client itself. To give a client a dedicated session, pass a `URLSessionConfiguration`; the client creates that session once, owns it, and invalidates it (`finishTasksAndInvalidate()`) when the client is deallocated:

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 10
let client = IPDataClient(apiKey: "YOUR_API_KEY", configuration: configuration)
```

You can still inject a ready-made `URLSession` with `IPDataClient(apiKey:baseURL:session:)`, for example one with a custom delegate or a mock `URLProtocol` in tests; the client never invalidates a session it did not create.

`IPDataClient` is immutable and `Sendable`: share one instance across threads and Swift concurrency tasks. There is nothing to close explicitly; let the client be released and its owned session, if it has one, is invalidated for you (`URLSession.shared` is never invalidated).

A bulk lookup (`POST /bulk`) that fails with `URLError.networkConnectionLost`, typically because the server closed an idle pooled connection, is sent once more over a fresh connection. No other request is retried by the client, and nothing is retried once an HTTP status has been received.

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
        print("Listed on: \(entry.name ?? "") (\(entry.type ?? ""))")
        if let firstSeen = entry.firstSeen, let lastSeen = entry.lastSeen {
            print("  seen \(firstSeen) to \(lastSeen), \(entry.daysSeen ?? 0) day(s)")
        }
    }
}
```

### Satellite and Anycast Flags

`isSatellite` and `isAnycast` are plain `Bool`s. The API includes `is_satellite` and `is_anycast` in a response only when they are true, so both read `false` whenever the key is absent:

```swift
let info = try await client.lookup("8.8.8.8")
if info.isAnycast {
    print("anycast address")
}
if info.isSatellite {
    print("satellite internet provider")
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
| `isSatellite` | `Bool` | Satellite internet provider. The API sends `is_satellite` only when it is true; reads `false` when the key is absent |
| `isAnycast` | `Bool` | Anycast address. The API sends `is_anycast` only when it is true; reads `false` when the key is absent |
| `city` | `String?` | City name |
| `region` | `String?` | Region / state |
| `regionCode` | `String?` | Region code |
| `regionType` | `String?` | Kind of region (for example `state` or `province`) |
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
| `emojiUnicode` | `String?` | Flag emoji as Unicode code points (for example `U+1F1FA U+1F1F8`) |
| `asn` | `ASN?` | Autonomous system info |
| `company` | `Company?` | Organization that owns the IP |
| `carrier` | `Carrier?` | Mobile carrier info |
| `languages` | `[Language]?` | Languages spoken in the country |
| `currency` | `Currency?` | Local currency |
| `timeZone` | `TimeZoneInfo?` | Time zone details |
| `threat` | `Threat?` | Threat intelligence data |
| `count` | `Int?` | API requests in last 24 hours |

### ASNDetail

Detailed ASN data from the dedicated `/asn` endpoint. Includes `ipv4Prefixes`, `ipv6Prefixes`, `numIPs`, `upstream`, `downstream`, and `peers`.

### TimeZoneInfo

Time zone of the IP address location: `name`, `abbr`, `offset`, `isDST` and `currentTime`. The type is called `TimeZoneInfo` so that it does not shadow Foundation's `TimeZone`.

### Threat

Threat intelligence flags: `isTor`, `isVPN`, `isICloudRelay`, `isProxy`, `isDatacenter`, `isAnonymous`, `isKnownAttacker`, `isKnownAbuser`, `isThreat`, `isBogon`. Includes `blocklists` and reputation `scores` (0-100 for VPN, proxy, threat, and trust).

### Blocklist

One entry per list in `threat.blocklists`:

| Property | Type | Description |
|---|---|---|
| `name` | `String?` | Name of the blocklist |
| `site` | `String?` | Website of the blocklist |
| `type` | `String?` | Kind of list (`vpn`, `cloud`, `general`, ...) |
| `firstSeen` | `String?` | First day the IP was seen on the list, `YYYY-MM-DD` (UTC) |
| `lastSeen` | `String?` | Last day the IP was seen on the list, `YYYY-MM-DD` (UTC) |
| `daysSeen` | `Int?` | Number of days the IP has been seen on the list |

Some feeds, such as ipdata's own VPN feed, omit `firstSeen`, `lastSeen` and `daysSeen`; those entries decode with the three properties set to `nil`. The dates are kept as strings exactly as the API sends them.

All model types conform to `Codable`, `Sendable`, and `Equatable`.
