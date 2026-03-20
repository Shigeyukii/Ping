# Test Coverage Analysis — Ping App

## Current State

The project has **0% effective test coverage**. Three test files exist, but all contain only Xcode boilerplate with no assertions or logic.

| File | Lines | Actual tests |
|------|-------|--------------|
| `TESTTests/TESTTests.swift` | 17 | 0 (empty `@Test func example()`) |
| `TESTUITests/TESTUITests.swift` | 41 | 0 (launches app, no assertions) |
| `TESTUITests/TESTUITestsLaunchTests.swift` | 33 | 0 (screenshot only) |

---

## Source Code Under Test

All meaningful logic lives in `Ping/ContentView.swift` (373 lines):

- **`PingResult`** (lines 7–19) — value type / data model
- **`PingManager`** (lines 23–172) — async business logic
- **`PingView`** (lines 176–373) — SwiftUI UI layer

---

## Proposed Improvements, Ranked by Priority

### 1. `PingResult` model — computed properties (HIGH)

**What to test:** `isSuccess` and `displayTime`

These are pure, side-effect-free computed properties — the easiest possible tests to write.

```swift
// isSuccess
#expect(PingResult(seq:1, host:"h", responseTime:42.0, timestamp:.now).isSuccess == true)
#expect(PingResult(seq:1, host:"h", responseTime:nil,  timestamp:.now).isSuccess == false)

// displayTime
#expect(PingResult(seq:1, host:"h", responseTime:42.5, timestamp:.now).displayTime == "42.5 ms")
#expect(PingResult(seq:1, host:"h", responseTime:nil,  timestamp:.now).displayTime == "タイムアウト")
```

**Why it matters:** Any future change to the formatting string or success logic would silently break with no safety net.

---

### 2. `PingManager.stats` computed property (HIGH)

**What to test:** The stats tuple — sent, received, lost, min, max, avg.

`stats` is a pure computation over `self.results`. You can inject results directly without any async or network calls.

Scenarios to cover:
- Empty results → all zeros
- All successes → lost == 0, correct min/max/avg
- All timeouts → received == 0, lost == sent, min/max/avg == 0
- Mixed results → correct packet loss count and average (excludes `nil` times)
- Single result → min == max == avg

**Why it matters:** The avg calculation uses `max(success, 1)` in `start()` but `times.count` in `stats` — these two paths are inconsistent and a test would catch a regression.

---

### 3. `PingManager.isIPAddress` — IP validation (HIGH)

This private method gates whether DNS resolution is skipped. It can be tested by making it `internal` (or via `@testable import`) and covering:

| Input | Expected |
|-------|----------|
| `"192.168.1.1"` | `true` |
| `"0.0.0.0"` | `true` |
| `"255.255.255.255"` | `true` |
| `"256.0.0.1"` | `false` |
| `"::1"` | `true` (IPv6 loopback) |
| `"2001:db8::1"` | `true` |
| `"google.com"` | `false` |
| `""` | `false` |
| `"not-an-ip"` | `false` |

**Why it matters:** A bug here means a valid IP is resolved via DNS unnecessarily (wasted latency), or a hostname is passed directly to `NWConnection` without resolution.

---

### 4. `PingManager.start` — state transitions (MEDIUM)

Test the observable state machine without a real network:

- After `start()` is called: `isRunning == true`, `results` is empty, `statusMessage` begins with "解決中..."
- After `stop()` is called mid-run: `isRunning == false`
- After a completed run: `isRunning == false`, `statusMessage` contains "完了"

This requires either mocking `resolveHost`/`tcpPing` (by extracting them to a protocol/closure) or using `XCTestExpectation` with a timeout. The cleanest approach is to extract network dependencies behind a protocol so tests can inject a fake.

---

### 5. `PingManager.resolveHost` — DNS resolution (MEDIUM)

Currently, `resolveHost` calls `getaddrinfo` directly, making it impossible to test without a live network. Two sub-cases to cover once mockable:

- Input is already an IP → returns immediately without DNS lookup
- Hostname resolves successfully → returns IP string
- Hostname does not exist → returns `nil`

**Refactoring needed:** Extract the DNS call behind a closure or protocol to allow injection of a fake resolver in tests.

---

### 6. `PingManager.tcpPing` — TCP round-trip measurement (MEDIUM)

Currently untestable without a live network. To test:

- Successful connection → returns a non-nil `Double` (RTT in ms)
- Failed connection → returns `nil`
- Timeout fires before connection → returns `nil`

**Refactoring needed:** Extract `NWConnection` creation behind a factory/protocol so tests can inject a fake connection that immediately moves to `.ready`, `.failed`, or stalls.

---

### 7. `responseColor` helper (LOW)

Pure function in `PingView`:

```swift
// ms < 50  → .green
// ms < 150 → .orange
// ms >= 150 → .red
```

Boundary values to test: 49, 50, 149, 150.

---

### 8. UI tests — basic interaction (LOW)

The existing `TESTUITests.swift` launches the app but asserts nothing. Add at minimum:

- App launches and "Ping" navigation title is visible
- Default host field contains "google.com"
- Tapping "開始" button changes it to "停止"
- Tapping "停止" returns to "開始"

These are resilient smoke tests that catch total regressions without needing network access.

---

## Recommended Refactoring to Enable Testing

The biggest blocker is that `PingManager` directly owns its network dependencies. Introduce a simple protocol:

```swift
protocol PingTransport {
    func tcpPing(host: String, port: UInt16, timeout: Double) async -> Double?
    func resolveHost(_ host: String) async -> String?
}
```

Inject it into `PingManager` via initializer. Production code uses the real implementation; tests inject a `FakePingTransport` that returns controlled values synchronously.

---

## Summary Table

| Area | Priority | Requires refactor? | Effort |
|------|----------|--------------------|--------|
| `PingResult` computed properties | High | No | Low |
| `PingManager.stats` | High | No | Low |
| `isIPAddress` validation | High | No (make internal) | Low |
| State transitions in `start`/`stop` | Medium | Partial | Medium |
| `resolveHost` DNS logic | Medium | Yes (protocol) | Medium |
| `tcpPing` network logic | Medium | Yes (protocol) | Medium |
| `responseColor` | Low | No | Low |
| UI smoke tests | Low | No | Low |
