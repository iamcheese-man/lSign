import Foundation

@objc public class ZipHelper: NSObject {

    @objc public class func unzipIPA(at ipaURL: URL, to destinationURL: URL) -> Bool {
        do {
            // Rename .ipa to .zip (IPAs are zip files)
            let zipURL = destinationURL.appendingPathComponent("input.zip")
            try FileManager.default.copyItem(at: ipaURL, to: zipURL)
            
            // Create Payload directory
            let payloadURL = destinationURL.appendingPathComponent("Payload")
            try FileManager.default.createDirectory(at: payloadURL, withIntermediateDirectories: true, attributes: nil)
            
            // Unzip using built-in Swift API
            try FileManager.default.unzipItem(at: zipURL, to: destinationURL)
            
            // Clean up the temporary zip
            try? FileManager.default.removeItem(at: zipURL)
            
            return true
        } catch {
            print("[ZipHelper] Unzip failed: \(error.localizedDescription)")
            return false
        }
    }
}
