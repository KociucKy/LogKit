#if canImport(SwiftUI)
import SwiftUI

// MARK: - ScreenAnalyticsModifier

/// A `ViewModifier` that automatically fires screen appear and disappear
/// analytics events by reading ``LogManager`` from the SwiftUI environment.
///
/// Prefer the `.screenAppearAnalytics(name:)` convenience extension on `View`
/// over using this modifier directly.
private struct ScreenAnalyticsModifier: ViewModifier {

    @Environment(LogManager.self) private var logManager

    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                logManager.trackScreenEvent(
                    event: AnyLoggableEvent(
                        eventName: "\(screenName)_Appear",
                        type: .analytic
                    )
                )
            }
            .onDisappear {
                logManager.trackEvent(
                    event: AnyLoggableEvent(
                        eventName: "\(screenName)_Disappear",
                        type: .analytic
                    )
                )
            }
    }
}

// MARK: - View extension

public extension View {

    /// Automatically tracks screen appear and disappear events.
    ///
    /// Fires `{name}_Appear` (via `trackScreenEvent`) when the view appears
    /// and `{name}_Disappear` (via `trackEvent`) when it disappears.
    ///
    /// Requires a ``LogManager`` instance to be present in the SwiftUI
    /// environment (injected via `.environment(logManager)`).
    ///
    /// ```swift
    /// struct ExploreView: View {
    ///     var body: some View {
    ///         List { ... }
    ///             .screenAppearAnalytics(name: "ExploreView")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter name: The screen name used as the event prefix.
    ///   Follow the `{ComponentName}` convention — the `_Appear` /
    ///   `_Disappear` suffixes are appended automatically.
    func screenAppearAnalytics(name: String) -> some View {
        modifier(ScreenAnalyticsModifier(screenName: name))
    }
}

#endif
