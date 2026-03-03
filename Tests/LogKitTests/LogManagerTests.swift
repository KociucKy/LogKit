import Testing
import LogKit

// MARK: - Helpers

/// A concrete LoggableEvent used only in tests to verify typed overloads.
private struct TestEvent: LoggableEvent, @unchecked Sendable {
    let eventName: String
    let type: LogType
    let parameters: [String: Any]?
}

// MARK: - LogManagerTests

@MainActor
struct LogManagerTests {

    // MARK: trackEvent(event: some LoggableEvent)

    @Test func trackEvent_typedOverload_forwardsToAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])
        let event = TestEvent(eventName: "Test_Event", type: .analytic, parameters: nil)

        manager.trackEvent(event: event)

        #expect(sink1.events.count == 1)
        #expect(sink1.events.first?.eventName == "Test_Event")
        #expect(sink2.events.count == 1)
        #expect(sink2.events.first?.eventName == "Test_Event")
    }

    @Test func trackEvent_typedOverload_preservesType() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])
        let event = TestEvent(eventName: "Warn_Event", type: .warning, parameters: nil)

        manager.trackEvent(event: event)

        #expect(sink.events.first?.type == .warning)
    }

    @Test func trackEvent_typedOverload_preservesParameters() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])
        let event = TestEvent(eventName: "Param_Event", type: .analytic, parameters: ["key": "value"])

        manager.trackEvent(event: event)

        #expect(sink.events.first?.parameters?["key"] as? String == "value")
    }

    // MARK: trackEvent(event: AnyLoggableEvent)

    @Test func trackEvent_anyLoggableEventOverload_forwardsToAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])
        let event = AnyLoggableEvent(eventName: "AnyEvent", type: .analytic)

        manager.trackEvent(event: event)

        #expect(sink1.events.count == 1)
        #expect(sink1.lastEventName == "AnyEvent")
        #expect(sink2.events.count == 1)
        #expect(sink2.lastEventName == "AnyEvent")
    }

    // MARK: trackEvent(eventName:type:parameters:)

    @Test func trackEvent_rawStringOverload_forwardsCorrectName() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.trackEvent(eventName: "Raw_Event")

        #expect(sink.lastEventName == "Raw_Event")
    }

    @Test func trackEvent_rawStringOverload_defaultsToAnalyticType() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.trackEvent(eventName: "Raw_Event")

        #expect(sink.events.first?.type == .analytic)
    }

    @Test func trackEvent_rawStringOverload_forwardsCustomType() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.trackEvent(eventName: "Severe_Event", type: .severe)

        #expect(sink.events.first?.type == .severe)
    }

    @Test func trackEvent_rawStringOverload_forwardsParameters() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.trackEvent(eventName: "Param_Event", parameters: ["count": 42])

        #expect(sink.events.first?.parameters?["count"] as? Int == 42)
    }

    // MARK: trackScreenEvent

    @Test func trackScreenEvent_forwardsToScreenEventsOnAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])
        let event = TestEvent(eventName: "HomeView_Appear", type: .analytic, parameters: nil)

        manager.trackScreenEvent(event: event)

        #expect(sink1.screenEvents.count == 1)
        #expect(sink1.lastScreenEventName == "HomeView_Appear")
        #expect(sink2.screenEvents.count == 1)
        #expect(sink2.lastScreenEventName == "HomeView_Appear")
    }

    @Test func trackScreenEvent_doesNotRecordInRegularEvents() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])
        let event = TestEvent(eventName: "HomeView_Appear", type: .analytic, parameters: nil)

        manager.trackScreenEvent(event: event)

        #expect(sink.events.isEmpty)
    }

    // MARK: identifyUser

    @Test func identifyUser_forwardsToAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])

        manager.identifyUser(userId: "u123", name: "Alice", email: "alice@example.com")

        #expect(sink1.identifiedUsers.count == 1)
        #expect(sink1.identifiedUsers.first?.userId == "u123")
        #expect(sink1.identifiedUsers.first?.name == "Alice")
        #expect(sink1.identifiedUsers.first?.email == "alice@example.com")
        #expect(sink2.identifiedUsers.count == 1)
    }

    @Test func identifyUser_nilNameAndEmail() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.identifyUser(userId: "anon42")

        #expect(sink.identifiedUsers.first?.userId == "anon42")
        #expect(sink.identifiedUsers.first?.name == nil)
        #expect(sink.identifiedUsers.first?.email == nil)
    }

    // MARK: addUserProperties

    @Test func addUserProperties_forwardsToAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])

        manager.addUserProperties(dict: ["plan": "pro"], isHighPriority: true)

        #expect(sink1.userProperties.count == 1)
        #expect(sink1.userProperties.first?.dict["plan"] as? String == "pro")
        #expect(sink1.userProperties.first?.isHighPriority == true)
        #expect(sink2.userProperties.count == 1)
    }

    @Test func addUserProperties_lowPriority_forwardsFlag() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.addUserProperties(dict: ["ab_test": "variant_b"], isHighPriority: false)

        #expect(sink.userProperties.first?.isHighPriority == false)
    }

    // MARK: deleteUserProfile

    @Test func deleteUserProfile_forwardsToAllSinks() {
        let sink1 = MockLogService()
        let sink2 = MockLogService()
        let manager = LogManager(services: [sink1, sink2])

        manager.deleteUserProfile()

        #expect(sink1.deleteUserProfileCallCount == 1)
        #expect(sink2.deleteUserProfileCallCount == 1)
    }

    // MARK: Empty services

    @Test func noSinks_doesNotCrash() {
        let manager = LogManager(services: [])

        // None of these should crash with zero sinks
        manager.trackEvent(eventName: "Ghost_Event")
        manager.trackScreenEvent(event: AnyLoggableEvent(eventName: "Ghost_Screen"))
        manager.identifyUser(userId: "nobody")
        manager.addUserProperties(dict: [:], isHighPriority: true)
        manager.deleteUserProfile()
    }

    // MARK: Multiple events

    @Test func trackEvent_multipleEvents_recordedInOrder() {
        let sink = MockLogService()
        let manager = LogManager(services: [sink])

        manager.trackEvent(eventName: "First")
        manager.trackEvent(eventName: "Second")
        manager.trackEvent(eventName: "Third")

        #expect(sink.events.map(\.eventName) == ["First", "Second", "Third"])
    }
}
