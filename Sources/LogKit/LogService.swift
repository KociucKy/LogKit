/// The contract every analytics/logging sink must satisfy.
///
/// Implement this protocol in your app (or in a thin adapter module) for each
/// third-party backend you want to integrate — TelemetryDeck, Crashlytics,
/// Mixpanel, etc. LogKit itself has no dependency on any of those SDKs.
///
/// ### Minimal example — TelemetryDeck adapter
/// ```swift
/// import LogKit
/// import TelemetryDeck
///
/// final class TelemetryDeckService: LogService {
///     func trackEvent(event: any LoggableEvent) {
///         guard event.type != .info else { return }
///         let params = event.parameters?.compactMapValues { "\($0)" } ?? [:]
///         TelemetryDeck.signal(event.eventName, parameters: params)
///     }
///
///     func trackScreenEvent(event: any LoggableEvent) {
///         trackEvent(event: event)
///     }
///
///     func identifyUser(userId: String, name: String?, email: String?) {}
///     func addUserProperties(dict: [String: Any], isHighPriority: Bool) {}
///     func deleteUserProfile() {}
/// }
/// ```
///
/// ### Minimal example — Crashlytics adapter
/// ```swift
/// import LogKit
/// import FirebaseCrashlytics
///
/// final class CrashlyticsService: LogService {
///     func trackEvent(event: any LoggableEvent) {
///         guard event.type == .severe else { return }
///         let code = event.eventName.djb2hash
///         let error = NSError(domain: event.eventName, code: code)
///         Crashlytics.crashlytics().record(error: error)
///     }
///
///     func trackScreenEvent(event: any LoggableEvent) {}
///
///     func identifyUser(userId: String, name: String?, email: String?) {
///         Crashlytics.crashlytics().setUserID(userId)
///     }
///
///     func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
///         guard isHighPriority else { return }
///         dict.forEach { Crashlytics.crashlytics().setCustomValue($0.value, forKey: $0.key) }
///     }
///
///     func deleteUserProfile() {}
/// }
/// ```
public protocol LogService: Sendable {

    // MARK: - Event tracking

    /// Records a standard event.
    ///
    /// Sinks should use `event.type` to decide whether to forward the event.
    /// Most production sinks suppress ``LogType/info`` events.
    func trackEvent(event: any LoggableEvent)

    /// Records a screen-view event.
    ///
    /// Some backends (e.g. Firebase Analytics) have a dedicated screen-view
    /// API. Sinks that don't distinguish between screen and regular events can
    /// simply delegate to ``trackEvent(event:)``.
    func trackScreenEvent(event: any LoggableEvent)

    // MARK: - User identity

    /// Associates all subsequent events with the given user.
    ///
    /// Call this as soon as a user signs in. Pass `nil` for fields that are
    /// unavailable (e.g. anonymous users have no email).
    func identifyUser(userId: String, name: String?, email: String?)

    /// Attaches persistent key-value properties to the current user profile.
    ///
    /// - Parameters:
    ///   - dict: The properties to set. Values should be primitive types.
    ///   - isHighPriority: When `true` the sink should always record the
    ///     properties (e.g. auth state, subscription status). When `false`
    ///     the sink may skip them to stay within backend quota limits (e.g.
    ///     Firebase's 25-property cap). AB test flags are a typical
    ///     low-priority payload.
    func addUserProperties(dict: [String: Any], isHighPriority: Bool)

    /// Removes all user-specific data from the sink's backend profile.
    ///
    /// Call this on sign-out or account deletion.
    func deleteUserProfile()
}
