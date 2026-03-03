import OSLog

// MARK: - LogSystem

/// A serialised wrapper around `os.Logger` that can be called safely from any
/// concurrency context.
///
/// Being an `actor` guarantees that concurrent `log` calls are queued and
/// never interleave. The `nonisolated` entry point lets callers fire-and-forget
/// without ever suspending — it simply enqueues a `Task` onto the actor.
private actor LogSystem {

    private let logger: Logger

    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    // Isolated — called only from within the actor.
    private func log(level: OSLogType, message: String) {
        logger.log(level: level, "\(message, privacy: .public)")
    }

    // Callable from any context without suspending the caller.
    nonisolated func log(type: LogType, message: String) {
        Task {
            await log(level: type.osLogType, message: message)
        }
    }
}

// MARK: - ConsoleService

/// A ``LogService`` sink that writes events to the unified logging system
/// (`os.Logger` / Console.app) during development.
///
/// Use this sink in debug builds. For release builds, omit it from the
/// `LogManager` services array so no log output is produced.
///
/// ```swift
/// // Debug
/// LogManager(services: [ConsoleService(printParameters: true), ...])
///
/// // Release
/// LogManager(services: [TelemetryDeckService(), CrashlyticsService()])
/// ```
public final class ConsoleService: LogService {

    private let logSystem: LogSystem
    private let printParameters: Bool

    /// Creates a console sink.
    ///
    /// - Parameters:
    ///   - subsystem: The OSLog subsystem identifier. Defaults to the main
    ///     bundle identifier, falling back to `"LogKit"`.
    ///   - category: The OSLog category. Defaults to `"analytics"`.
    ///   - printParameters: When `true`, event parameters are printed beneath
    ///     each event line. Set to `false` to reduce noise.
    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "LogKit",
        category: String = "analytics",
        printParameters: Bool = true
    ) {
        self.logSystem = LogSystem(subsystem: subsystem, category: category)
        self.printParameters = printParameters
    }

    // MARK: LogService — event tracking

    public func trackEvent(event: any LoggableEvent) {
        let message = buildMessage(event: event, prefix: event.type.logPrefix)
        logSystem.log(type: event.type, message: message)
    }

    public func trackScreenEvent(event: any LoggableEvent) {
        let message = buildMessage(event: event, prefix: "📱")
        logSystem.log(type: event.type, message: message)
    }

    // MARK: LogService — user identity

    public func identifyUser(userId: String, name: String?, email: String?) {
        var parts = ["userId: \(userId)"]
        if let name  { parts.append("name: \(name)") }
        if let email { parts.append("email: \(email)") }
        logSystem.log(type: .info, message: "👤 identifyUser — \(parts.joined(separator: ", "))")
    }

    public func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        guard printParameters else { return }
        let priority = isHighPriority ? "high" : "low"
        let props = dict.sorted { $0.key < $1.key }
            .map { "  \($0.key): \($0.value)" }
            .joined(separator: "\n")
        logSystem.log(type: .info, message: "🗂️ addUserProperties [\(priority)]\n\(props)")
    }

    public func deleteUserProfile() {
        logSystem.log(type: .info, message: "🗑️ deleteUserProfile")
    }

    // MARK: - Private helpers

    private func buildMessage(event: any LoggableEvent, prefix: String) -> String {
        var message = "\(prefix) \(event.eventName)"
        if printParameters, let parameters = event.parameters, !parameters.isEmpty {
            let paramLines = parameters.sorted { $0.key < $1.key }
                .map { "  \($0.key): \($0.value)" }
                .joined(separator: "\n")
            message += "\n\(paramLines)"
        }
        return message
    }
}

// MARK: - LogType helpers

private extension LogType {

    /// Maps ``LogType`` to the corresponding `OSLogType` level.
    var osLogType: OSLogType {
        switch self {
        case .info:     return .debug
        case .analytic: return .info
        case .warning:  return .error
        case .severe:   return .fault
        }
    }

    /// A short emoji prefix that makes log lines instantly scannable in Xcode
    /// and Console.app.
    var logPrefix: String {
        switch self {
        case .info:     return "👋"
        case .analytic: return "📈"
        case .warning:  return "⚠️"
        case .severe:   return "🚨"
        }
    }
}
