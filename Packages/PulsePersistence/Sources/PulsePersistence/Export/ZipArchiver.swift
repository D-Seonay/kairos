import Foundation

/// Zippe un dossier avec l'API système (`NSFileCoordinator`, option `forUploading`), sans dépendance.
enum ZipArchiver {
    enum ZipError: Error {
        case failed(String)
    }

    static func zip(directory: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: (any Error)?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: [.forUploading], error: &coordinationError) { zipURL in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw ZipError.failed(coordinationError.localizedDescription) }
        if let copyError { throw copyError }
    }
}
