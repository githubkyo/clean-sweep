import Foundation

struct PermissionChecker {
    /// Check if the app has Full Disk Access by trying to read a protected directory
    static func hasFullDiskAccess() -> Bool {
        let testPaths = [
            "/Library/Application Support/com.apple.TCC",
            "\(FileManager.default.homeDirectoryForCurrentUser.path())/Library/Safari",
        ]
        for path in testPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        return false
    }
}
