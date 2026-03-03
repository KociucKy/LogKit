# LogKit

A Swift 6 package for logging and analytics. LogKit provides a zero-dependency, strict-concurrency fan-out hub that forwards events to any number of analytics backends. You implement thin adapters for your chosen SDKs (TelemetryDeck, Crashlytics, Mixpanel, etc.) — LogKit itself has no third-party dependencies.

## Requirements

- Swift 6.0+
- iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+

## Installation

Add LogKit to your package or project via Swift Package Manager.

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/your-org/LogKit", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["LogKit"])
]
```

**In Xcode:** File → Add Package Dependencies → paste the repository URL.

---

## Architecture

```
 Presenter / Manager
        │
        ▼
   LogManager          (@MainActor, @Observable — fan-out hub)
        │
   ┌────┴──────────────────────┐
   ▼           ▼               ▼
ConsoleService  TelemetryDeckService  CrashlyticsService
(built-in)      (app-side adapter)   (app-side adapter)
```

| Type | Role |
|---|---|
| `LogService` | Protocol every sink must conform to |
| `LogManager` | Fan-out hub — forwards all calls to registered sinks |
| `LoggableEvent` | Protocol every event must conform to |
| `AnyLoggableEvent` | Type-erased concrete event for ad-hoc use and tests |
| `LogType` | Severity enum: `.info`, `.analytic`, `.warning`, `.severe` |
| `ConsoleService` | Built-in OSLog sink for development |
| `MockLogService` | Test double for unit testing |

---

## Quick Start

### 1. Set up `LogManager` at app startup

```swift
import LogKit

// Composition root — e.g. AppDelegate or @main struct
let logManager = LogManager(services: [
    ConsoleService(printParameters: true),  // dev only
    TelemetryDeckService(),                 // your adapter
    CrashlyticsService(),                   // your adapter
])
```

For release builds, omit `ConsoleService`:

```swift
let logManager = LogManager(services: [
    TelemetryDeckService(),
    CrashlyticsService(),
])
```

### 2. Inject into the SwiftUI environment

```swift
@main
struct MyApp: App {
    let logManager = LogManager(services: [...])

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(logManager)
    }
}
```

### 3. Track screen views automatically

```swift
struct HomeView: View {
    var body: some View {
        List { ... }
            .screenAppearAnalytics(name: "HomeView")
        // fires HomeView_Appear on appear
        // fires HomeView_Disappear on disappear
    }
}
```

### 4. Define events per component

The recommended pattern is a nested `Event` enum inside each presenter, manager, or view model:

```swift
import LogKit

final class PurchaseManager {
    private let logManager: LogManager

    func purchase(_ product: Product) async {
        logManager.trackEvent(event: Event.purchase_Start(productId: product.id))
        do {
            try await store.purchase(product)
            logManager.trackEvent(event: Event.purchase_Success(productId: product.id))
        } catch {
            logManager.trackEvent(event: Event.purchase_Fail(error: error))
        }
    }
}

private extension PurchaseManager {
    enum Event: LoggableEvent {
        case purchase_Start(productId: String)
        case purchase_Success(productId: String)
        case purchase_Fail(error: Error)

        var eventName: String {
            switch self {
            case .purchase_Start:   return "PurchaseMan_Purchase_Start"
            case .purchase_Success: return "PurchaseMan_Purchase_Success"
            case .purchase_Fail:    return "PurchaseMan_Purchase_Fail"
            }
        }

        var type: LogType {
            switch self {
            case .purchase_Fail: return .severe
            default:             return .analytic
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .purchase_Start(let id),
                 .purchase_Success(let id):  return ["product_id": id]
            case .purchase_Fail(let error):  return error.eventParameters
            }
        }
    }
}
```

### 5. Identify users

```swift
// On sign-in
logManager.identifyUser(userId: user.id, name: user.name, email: user.email)
logManager.addUserProperties(dict: user.eventParameters, isHighPriority: true)

// A/B test flags (low priority — sinks may skip to stay within quotas)
logManager.addUserProperties(dict: activeTests.eventParameters, isHighPriority: false)

// On sign-out or account deletion
logManager.deleteUserProfile()
```

---

## Event naming convention

Use the `{ComponentPrefix}_{Action}_{Lifecycle}` pattern to keep event names consistent and queryable across your analytics dashboards:

```
AuthMan_SignIn_Start
AuthMan_SignIn_Success
AuthMan_SignIn_Fail
ProfileView_LoadAvatar_Start
ProfileView_LoadAvatar_Success
ChatView_SendMessage_Sent
ChatView_SendMessage_Fail
```

Screen view events (fired by `.screenAppearAnalytics`) follow `{ViewName}_Appear` / `{ViewName}_Disappear`.

---

## Event parameters

Add an `eventParameters` computed property to your domain models and merge at the call site:

```swift
extension UserModel {
    var eventParameters: [String: Any] {
        [
            "user_id":           userId,
            "user_is_anonymous": isAnonymous,
            "user_plan":         plan,
        ]
    }
}

extension Error {
    var eventParameters: [String: Any] {
        ["error_description": localizedDescription]
    }
}
```

Merging multiple models:

```swift
var params = chat.eventParameters
params.merge(avatar.eventParameters)
params.merge(message.eventParameters)
logManager.trackEvent(eventName: "ChatView_SendMessage_Sent", parameters: params)
```

Use the `Dictionary.first(upTo:)` extension when a backend enforces a parameter count limit (e.g. Firebase Analytics caps at 25):

```swift
Analytics.logEvent(event.eventName, parameters: params.first(upTo: 25))
```

Use the `String` extensions when a backend enforces string length or format constraints:

```swift
let name  = event.eventName.clipped(maxCharacters: 40).replacingSpacesWithUnderscores()
let value = stringValue.clipped(maxCharacters: 100)
```

---

## Writing a custom sink

Conform to `LogService` in your app target (not in LogKit itself):

```swift
import LogKit
import TelemetryDeck

final class TelemetryDeckService: LogService {

    func trackEvent(event: any LoggableEvent) {
        guard event.type != .info else { return }
        let params = event.parameters?
            .compactMapValues { "\($0)" }
            .first(upTo: 10) ?? [:]
        TelemetryDeck.signal(
            event.eventName.replacingSpacesWithUnderscores(),
            parameters: params
        )
    }

    func trackScreenEvent(event: any LoggableEvent) {
        trackEvent(event: event)
    }

    func identifyUser(userId: String, name: String?, email: String?) {
        TelemetryDeck.updateDefaultUserID(to: userId)
    }

    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {}
    func deleteUserProfile() {}
}
```

```swift
import LogKit
import FirebaseCrashlytics

final class CrashlyticsService: LogService {

    func trackEvent(event: any LoggableEvent) {
        guard event.type == .severe else { return }
        let code = abs(event.eventName.hashValue)
        let error = NSError(
            domain: event.eventName,
            code: code,
            userInfo: event.parameters as? [String: Any]
        )
        Crashlytics.crashlytics().record(error: error)
    }

    func trackScreenEvent(event: any LoggableEvent) {}

    func identifyUser(userId: String, name: String?, email: String?) {
        Crashlytics.crashlytics().setUserID(userId)
    }

    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        guard isHighPriority else { return }
        dict.forEach { Crashlytics.crashlytics().setCustomValue($0.value, forKey: $0.key) }
    }

    func deleteUserProfile() {}
}
```

---

## Testing

LogKit ships a `MockLogService` in the test target that records every call:

```swift
import Testing
import LogKit

@MainActor
struct PurchaseManagerTests {

    @Test func purchase_success_tracksCorrectEvents() async throws {
        let mock = MockLogService()
        let manager = LogManager(services: [mock])
        let sut = PurchaseManager(logManager: manager)

        try await sut.purchase(Product.mock)

        #expect(mock.events[0].eventName == "PurchaseMan_Purchase_Start")
        #expect(mock.events[1].eventName == "PurchaseMan_Purchase_Success")
        #expect(mock.events.count == 2)
    }

    @Test func purchase_failure_tracksSevereEvent() async {
        let mock = MockLogService()
        let manager = LogManager(services: [mock])
        let sut = PurchaseManager(logManager: manager, store: FailingStoreMock())

        await sut.purchase(Product.mock)

        #expect(mock.lastEventName == "PurchaseMan_Purchase_Fail")
        #expect(mock.events.last?.type == .severe)
    }
}
```

`MockLogService` API:

| Property | Description |
|---|---|
| `events` | All events from `trackEvent`, in order |
| `screenEvents` | All events from `trackScreenEvent`, in order |
| `lastEventName` | Shorthand for `events.last?.eventName` |
| `lastScreenEventName` | Shorthand for `screenEvents.last?.eventName` |
| `identifiedUsers` | All `identifyUser` call arguments |
| `userProperties` | All `addUserProperties` call arguments |
| `deleteUserProfileCallCount` | Number of `deleteUserProfile` calls |
| `reset()` | Clears all recorded state |

---

## LogType severity guide

| Value | Use for | Sink behaviour |
|---|---|---|
| `.info` | Lifecycle noise, debug breadcrumbs | Console only; production sinks should suppress |
| `.analytic` | Standard business events | All production sinks record |
| `.warning` | Unexpected but recoverable state | All production sinks record |
| `.severe` | User-impacting errors | All sinks record; Crashlytics records as non-fatal error |

---

## File structure

```
Sources/LogKit/
├── LogManager.swift                    # Fan-out hub (@MainActor, @Observable)
├── LogService.swift                    # Sink protocol
├── Models/
│   ├── LogType.swift                   # Severity enum
│   └── LoggableEvent.swift             # Event protocol + AnyLoggableEvent
├── Services/
│   └── ConsoleService.swift            # OSLog sink (actor LogSystem)
├── SwiftUI/
│   └── ScreenAnalyticsModifier.swift   # .screenAppearAnalytics(name:)
└── Extensions/
    ├── String+Ext.swift                # clipped(maxCharacters:), replacingSpacesWithUnderscores()
    └── Dictionary+Ext.swift            # merge(_:), first(upTo:)

Tests/LogKitTests/
├── MockLogService.swift                # Test double
├── LogManagerTests.swift               # 17 tests — fan-out, all overloads
└── ConsoleServiceTests.swift           # 14 tests — conformance + smoke
```

---

## Swift 6 concurrency notes

- `LogManager` is `@MainActor` — all public API is called on the main actor, matching the natural call site (UI code, `@MainActor` managers)
- `LogService` is `Sendable` — sinks can be safely stored in the `[any LogService]` array
- `LoggableEvent` is `Sendable` — events can be passed across actor boundaries
- `AnyLoggableEvent` uses `@unchecked Sendable` because `[String: Any]` contains `Any`, which is not formally `Sendable`. In practice analytics parameters are always value types (`String`, `Int`, `Double`, `Bool`, `Date`), making this safe
- `ConsoleService` uses a private `actor LogSystem` with a `nonisolated` entry point — log writes are serialised without blocking callers

---

## License

MIT
