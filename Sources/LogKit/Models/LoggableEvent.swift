/// The contract every loggable event must satisfy.
///
/// Conform to this protocol in a nested `Event` enum inside each component
/// (presenter, manager, view model) to keep event definitions co-located with
/// the code that emits them. For example:
///
/// ```swift
/// private extension ProfilePresenter {
///     enum Event: LoggableEvent {
///         case loadAvatar_Start
///         case loadAvatar_Success
///         case loadAvatar_Fail(error: Error)
///
///         var eventName: String {
///             switch self {
///             case .loadAvatar_Start:   return "ProfileView_LoadAvatar_Start"
///             case .loadAvatar_Success: return "ProfileView_LoadAvatar_Success"
///             case .loadAvatar_Fail:    return "ProfileView_LoadAvatar_Fail"
///             }
///         }
///
///         var type: LogType {
///             switch self {
///             case .loadAvatar_Fail: return .severe
///             default:               return .analytic
///             }
///         }
///
///         var parameters: [String: Any]? {
///             switch self {
///             case .loadAvatar_Fail(let error): return error.eventParameters
///             default:                          return nil
///             }
///         }
///     }
/// }
/// ```
///
/// ### Naming convention
/// `{ComponentPrefix}_{Action}_{Lifecycle}`, e.g.:
/// - `ProfileView_LoadAvatar_Start`
/// - `AuthMan_SignOut_Success`
/// - `ChatView_SendMessage_Fail`
public protocol LoggableEvent: Sendable {

    /// The unique name sent to every analytics sink.
    ///
    /// Use the `{ComponentPrefix}_{Action}_{Lifecycle}` convention and keep
    /// names stable across releases — renaming breaks historical data.
    var eventName: String { get }

    /// Severity and intent of the event. Sinks use this to filter or route.
    var type: LogType { get }

    /// Optional key-value payload attached to the event.
    ///
    /// Values should be primitive types (`String`, `Int`, `Double`, `Bool`,
    /// `Date`) so every sink can serialise them without loss. Avoid nesting.
    var parameters: [String: Any]? { get }
}

// MARK: - AnyLoggableEvent

/// A type-erased, concrete implementation of ``LoggableEvent``.
///
/// Use this for:
/// - Ad-hoc events constructed from raw strings (e.g. in `LogManager`
///   convenience overloads).
/// - Test doubles that need to store and compare captured events regardless
///   of their original concrete type.
public struct AnyLoggableEvent: LoggableEvent {

    public let eventName: String
    public let type: LogType
    public let parameters: [String: Any]?

    public init(
        eventName: String,
        type: LogType = .analytic,
        parameters: [String: Any]? = nil
    ) {
        self.eventName = eventName
        self.type = type
        self.parameters = parameters
    }

    /// Wraps any ``LoggableEvent`` into a type-erased container.
    public init(_ event: any LoggableEvent) {
        self.eventName = event.eventName
        self.type = event.type
        self.parameters = event.parameters
    }
}

// `parameters: [String: Any]?` contains `Any`, which is not `Sendable`.
// In practice analytics parameters are always value types (String, Int,
// Double, Bool, Date), so this is safe.
extension AnyLoggableEvent: @unchecked Sendable {}
