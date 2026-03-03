/// Classifies the severity and intent of a loggable event.
///
/// Sinks use this to decide whether to record an event and how to treat it.
/// For example, a Crashlytics sink typically only acts on `.severe`, while a
/// console sink prints all levels with distinct visual markers.
public enum LogType: Sendable {

    /// Pure diagnostic information. Most production sinks should suppress this.
    case info

    /// A standard analytics event (default for most tracking calls).
    case analytic

    /// A non-critical issue worth investigating but not user-impacting.
    case warning

    /// A user-impacting error. Sinks such as Crashlytics should record this
    /// as a non-fatal error.
    case severe
}
