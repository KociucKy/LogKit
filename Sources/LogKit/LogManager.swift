import Observation

/// The central fan-out hub that forwards every logging and analytics call to
/// all registered ``LogService`` sinks.
///
/// Create a single `LogManager` instance at app startup, configure it with
/// the sinks appropriate for the current build, and inject it into your
/// dependency graph (e.g. via the SwiftUI environment or a DI container).
///
/// ```swift
/// // Composition root (e.g. AppDelegate / @main)
/// let logManager = LogManager(services: [
///     ConsoleService(printParameters: true),   // dev only
///     TelemetryDeckService(),
///     CrashlyticsService(),
/// ])
/// ```
///
/// Because `LogManager` is `@MainActor` and `@Observable`, it can be placed
/// directly in the SwiftUI environment and read by view modifiers without
/// any extra wrappers:
///
/// ```swift
/// WindowGroup { ... }
///     .environment(logManager)
/// ```
@MainActor
@Observable
public final class LogManager {

    private let services: [any LogService]

    /// Creates a manager that forwards all calls to `services` in order.
    ///
    /// - Parameter services: The sinks to fan out to. Pass an empty array to
    ///   create a no-op manager (useful in unit tests that don't care about
    ///   logging).
    public init(services: [any LogService]) {
        self.services = services
    }

    // MARK: - Event tracking

    /// Forwards a ``LoggableEvent``-conforming value to all sinks.
    public func trackEvent(event: some LoggableEvent) {
        services.forEach { $0.trackEvent(event: event) }
    }

    /// Forwards a type-erased ``AnyLoggableEvent`` to all sinks.
    public func trackEvent(event: AnyLoggableEvent) {
        services.forEach { $0.trackEvent(event: event) }
    }

    /// Constructs an ``AnyLoggableEvent`` from raw components and forwards it
    /// to all sinks.
    ///
    /// Useful for one-off events where defining a dedicated `Event` enum case
    /// would be overkill.
    ///
    /// - Parameters:
    ///   - eventName: The event name. Follow the
    ///     `{ComponentPrefix}_{Action}_{Lifecycle}` convention.
    ///   - type: Severity. Defaults to ``LogType/analytic``.
    ///   - parameters: Optional key-value payload.
    public func trackEvent(
        eventName: String,
        type: LogType = .analytic,
        parameters: [String: Any]? = nil
    ) {
        let event = AnyLoggableEvent(eventName: eventName, type: type, parameters: parameters)
        services.forEach { $0.trackEvent(event: event) }
    }

    /// Forwards a screen-view event to all sinks.
    ///
    /// Sinks with a dedicated screen-view API (e.g. Firebase Analytics
    /// `AnalyticsEventScreenView`) should override the default behaviour in
    /// their ``LogService/trackScreenEvent(event:)`` implementation.
    public func trackScreenEvent(event: some LoggableEvent) {
        services.forEach { $0.trackScreenEvent(event: event) }
    }

    // MARK: - User identity

    /// Associates all subsequent events with the given user across all sinks.
    ///
    /// Call this as soon as a user signs in. Pass `nil` for fields that are
    /// unavailable (e.g. anonymous users typically have no name or email).
    ///
    /// - Parameters:
    ///   - userId: The stable, unique identifier for the user.
    ///   - name: Optional display name.
    ///   - email: Optional email address.
    public func identifyUser(userId: String, name: String? = nil, email: String? = nil) {
        services.forEach { $0.identifyUser(userId: userId, name: name, email: email) }
    }

    /// Attaches persistent key-value properties to the current user profile
    /// across all sinks.
    ///
    /// - Parameters:
    ///   - dict: The properties to set. Values should be primitive types
    ///     (`String`, `Int`, `Double`, `Bool`, `Date`).
    ///   - isHighPriority: Pass `true` for critical properties (auth state,
    ///     subscription status). Pass `false` for lower-signal data such as
    ///     A/B test flags — sinks may skip these to stay within backend quotas.
    public func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        services.forEach { $0.addUserProperties(dict: dict, isHighPriority: isHighPriority) }
    }

    /// Removes all user-specific data from every sink's backend profile.
    ///
    /// Call this on sign-out or account deletion.
    public func deleteUserProfile() {
        services.forEach { $0.deleteUserProfile() }
    }
}
