import Foundation

/// Localized string lookup helper.
/// - Parameters:
///   - key: Localization key from Localizable.strings
///   - args: Format arguments for interpolated strings
/// - Returns: Localized string
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: .localizedModule, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

extension Bundle {
    /// Resolves the correct `.lproj` bundle from `Bundle.module` based on system locale.
    /// SPM executable targets lack localization metadata in Bundle.main,
    /// so we resolve manually from `Locale.preferredLanguages`.
    static let localizedModule: Bundle = {
        let module = Bundle.module
        for language in Locale.preferredLanguages {
            let code = Locale(identifier: language).language.languageCode?.identifier ?? language
            if let path = module.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return module
    }()
}
