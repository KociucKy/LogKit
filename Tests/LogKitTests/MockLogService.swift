import LogKit

/// A test double for ``LogService`` that records every call made to it.
///
/// Use this in unit tests to assert that ``LogManager`` (or any component
/// that depends on a ``LogService``) calls the right methods with the right
/// arguments.
///
/// ```swift
/// let mock = MockLogService()
/// let manager = await LogManager(services: [mock])
///
/// await manager.trackEvent(eventName: "Test_Event")
///
/// XCTAssertEqual(mock.events.first?.eventName, "Test_Event")
/// ```
public final class MockLogService: LogService, @unchecked Sendable {

    // MARK: - Recorded calls

    /// All events received via ``trackEvent(event:)``, in order.
    public private(set) var events: [AnyLoggableEvent] = []

    /// All events received via ``trackScreenEvent(event:)``, in order.
    public private(set) var screenEvents: [AnyLoggableEvent] = []

    /// Arguments passed to each ``identifyUser(userId:name:email:)`` call.
    public private(set) var identifiedUsers: [(userId: String, name: String?, email: String?)] = []

    /// Arguments passed to each ``addUserProperties(dict:isHighPriority:)`` call.
    public private(set) var userProperties: [(dict: [String: Any], isHighPriority: Bool)] = []

    /// Number of times ``deleteUserProfile()`` was called.
    public private(set) var deleteUserProfileCallCount: Int = 0

    // MARK: - Convenience

    /// The name of the last event received via ``trackEvent(event:)``.
    public var lastEventName: String? { events.last?.eventName }

    /// The name of the last event received via ``trackScreenEvent(event:)``.
    public var lastScreenEventName: String? { screenEvents.last?.eventName }

    // MARK: - Init

    public init() {}

    // MARK: - Reset

    /// Clears all recorded calls. Useful for resetting state between tests.
    public func reset() {
        events = []
        screenEvents = []
        identifiedUsers = []
        userProperties = []
        deleteUserProfileCallCount = 0
    }

    // MARK: - LogService

    public func trackEvent(event: any LoggableEvent) {
        events.append(AnyLoggableEvent(event))
    }

    public func trackScreenEvent(event: any LoggableEvent) {
        screenEvents.append(AnyLoggableEvent(event))
    }

    public func identifyUser(userId: String, name: String?, email: String?) {
        identifiedUsers.append((userId: userId, name: name, email: email))
    }

    public func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        userProperties.append((dict: dict, isHighPriority: isHighPriority))
    }

    public func deleteUserProfile() {
        deleteUserProfileCallCount += 1
    }
}
