public extension Dictionary {

    /// Merges the entries of `other` into this dictionary in place.
    ///
    /// Existing keys are kept — values from `other` never overwrite existing
    /// ones. This mirrors the AIChat convention where the base model's
    /// parameters take precedence over additional context being merged in.
    ///
    /// ```swift
    /// var dict = chat.eventParameters        // ["chat_id": "abc"]
    /// dict.merge(avatar.eventParameters)     // adds avatar keys
    /// dict.merge(message.eventParameters)    // adds message keys
    /// ```
    mutating func merge(_ other: [Key: Value]?) {
        guard let other else { return }
        merge(other) { existing, _ in existing }
    }

    /// Returns a new dictionary containing only the first `maxCount`
    /// key-value pairs, ordered by key.
    ///
    /// Use this to stay within analytics backend parameter limits before
    /// sending an event (e.g. Firebase Analytics allows at most 25 custom
    /// parameters per event).
    ///
    /// ```swift
    /// let safe = params.first(upTo: 25)
    /// ```
    ///
    /// - Parameter maxCount: The maximum number of entries to keep.
    func first(upTo maxCount: Int) -> [Key: Value] where Key == String {
        guard count > maxCount else { return self }
        return Dictionary(
            uniqueKeysWithValues: sorted { $0.key < $1.key }.prefix(maxCount).map { ($0.key, $0.value) }
        )
    }
}
