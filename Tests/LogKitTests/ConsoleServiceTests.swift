import Testing
import LogKit

/// Smoke tests for ``ConsoleService``.
///
/// `ConsoleService` writes to `os.Logger` via a private actor, so there is
/// nothing to intercept or assert on the output side. These tests verify
/// that the service:
/// - Conforms to ``LogService`` and can be used anywhere one is expected
/// - Does not crash for any ``LogType`` value or any parameter combination
/// - Integrates cleanly with ``LogManager`` as a registered sink
@Suite("ConsoleService")
struct ConsoleServiceTests {

    // MARK: - Conformance

    @Test func conformsToLogService() {
        // Compile-time check: ConsoleService must be usable as a LogService.
        let service: any LogService = ConsoleService()
        _ = service
    }

    @Test func canBeRegisteredWithLogManager() async {
        // ConsoleService must be accepted by LogManager without crashing.
        let manager = await LogManager(services: [ConsoleService(printParameters: true)])
        await manager.trackEvent(eventName: "ConsoleService_Init_Success")
    }

    // MARK: - trackEvent — all LogType values

    @Test(arguments: [LogType.info, .analytic, .warning, .severe])
    func trackEvent_allLogTypes_doesNotCrash(type: LogType) {
        let service = ConsoleService()
        let event = AnyLoggableEvent(eventName: "Test_\(type)_Event", type: type)
        service.trackEvent(event: event)
    }

    @Test func trackEvent_withParameters_doesNotCrash() {
        let service = ConsoleService(printParameters: true)
        let event = AnyLoggableEvent(
            eventName: "Test_Params_Event",
            type: .analytic,
            parameters: [
                "string_key": "value",
                "int_key": 42,
                "bool_key": true,
                "double_key": 3.14
            ]
        )
        service.trackEvent(event: event)
    }

    @Test func trackEvent_withNilParameters_doesNotCrash() {
        let service = ConsoleService(printParameters: true)
        let event = AnyLoggableEvent(eventName: "Test_NoParams_Event", type: .analytic, parameters: nil)
        service.trackEvent(event: event)
    }

    @Test func trackEvent_printParametersFalse_doesNotCrash() {
        let service = ConsoleService(printParameters: false)
        let event = AnyLoggableEvent(
            eventName: "Test_Quiet_Event",
            type: .analytic,
            parameters: ["key": "value"]
        )
        service.trackEvent(event: event)
    }

    // MARK: - trackScreenEvent

    @Test func trackScreenEvent_doesNotCrash() {
        let service = ConsoleService()
        let event = AnyLoggableEvent(eventName: "HomeView_Appear", type: .analytic)
        service.trackScreenEvent(event: event)
    }

    // MARK: - User identity

    @Test func identifyUser_withAllFields_doesNotCrash() {
        let service = ConsoleService()
        service.identifyUser(userId: "u123", name: "Alice", email: "alice@example.com")
    }

    @Test func identifyUser_withNilFields_doesNotCrash() {
        let service = ConsoleService()
        service.identifyUser(userId: "anon99", name: nil, email: nil)
    }

    @Test func addUserProperties_highPriority_doesNotCrash() {
        let service = ConsoleService(printParameters: true)
        service.addUserProperties(dict: ["plan": "pro", "user_id": "u1"], isHighPriority: true)
    }

    @Test func addUserProperties_lowPriority_doesNotCrash() {
        let service = ConsoleService(printParameters: true)
        service.addUserProperties(dict: ["ab_flag": "variant_b"], isHighPriority: false)
    }

    @Test func addUserProperties_printParametersFalse_doesNotCrash() {
        let service = ConsoleService(printParameters: false)
        service.addUserProperties(dict: ["key": "value"], isHighPriority: true)
    }

    @Test func deleteUserProfile_doesNotCrash() {
        let service = ConsoleService()
        service.deleteUserProfile()
    }

    // MARK: - Custom subsystem / category

    @Test func customSubsystemAndCategory_doesNotCrash() {
        let service = ConsoleService(
            subsystem: "com.example.MyApp",
            category: "payments",
            printParameters: true
        )
        service.trackEvent(event: AnyLoggableEvent(eventName: "Payment_Complete", type: .analytic))
    }
}
