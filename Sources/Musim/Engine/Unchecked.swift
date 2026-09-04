import Foundation

/// Escape hatch to carry a non-Sendable value (a completion handler, an
/// AVAssetExportSession, …) into a `@Sendable` closure. Safe here because the
/// wrapped value is only ever touched after hopping back to the main actor.
final class Unchecked<T>: @unchecked Sendable {
    let v: T
    init(_ v: T) { self.v = v }
}
