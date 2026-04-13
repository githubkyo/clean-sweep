import Foundation

struct DeleteLogEntry: Sendable {
    enum Kind: Sendable {
        case success
        case trash
        case clipboard
        case skipped
        case error
        case summary
    }

    let kind: Kind
    let message: String
}
