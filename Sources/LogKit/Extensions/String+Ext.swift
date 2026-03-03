public extension String {

    /// Returns a copy of the string truncated to `maxCharacters`, appending
    /// an ellipsis (`…`) when truncation occurs.
    ///
    /// Useful for enforcing analytics backend limits on parameter values
    /// (e.g. Firebase Analytics caps string values at 100 characters).
    ///
    /// ```swift
    /// "Hello, world!".clipped(maxCharacters: 5) // "Hello…"
    /// "Hi".clipped(maxCharacters: 5)            // "Hi"
    /// ```
    func clipped(maxCharacters: Int) -> String {
        guard count > maxCharacters else { return self }
        return String(prefix(maxCharacters)) + "…"
    }

    /// Returns a copy of the string with every space replaced by an
    /// underscore.
    ///
    /// Useful for normalising event names and parameter keys before sending
    /// them to backends that don't allow spaces (e.g. Firebase Analytics).
    ///
    /// ```swift
    /// "hello world".replacingSpacesWithUnderscores() // "hello_world"
    /// ```
    func replacingSpacesWithUnderscores() -> String {
        replacingOccurrences(of: " ", with: "_")
    }
}
