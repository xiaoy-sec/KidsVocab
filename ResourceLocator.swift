import Foundation

enum ResourceLocator {
    private static let bundleSubdirectory = "Resources"

    static func bundleURL(relativePath: String) -> URL? {
        let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }

        let nsPath = trimmed as NSString
        let fileName = nsPath.lastPathComponent
        let dirPath = nsPath.deletingLastPathComponent

        let subdir = dirPath.isEmpty ? bundleSubdirectory : "\(bundleSubdirectory)/\(dirPath)"
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: subdir) {
            return url
        }
        let fallbackSubdir = dirPath.isEmpty ? nil : dirPath
        return Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: fallbackSubdir)
    }

    static func localOrRemoteURLString(relativePath: String) -> String? {
        if let local = bundleURL(relativePath: relativePath) {
            return local.absoluteString
        }
        return nil
    }

    static func localOrRemoteURL(relativePath: String) -> URL? {
        if let local = bundleURL(relativePath: relativePath) {
            return local
        }
        return nil
    }
}
