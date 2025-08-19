import Foundation
import AVFoundation
import os

#if canImport(Speech)
import Speech
#endif

/// Transcription service that leverages the new SpeechAnalyzer / SpeechTranscriber API available on macOS 26 (Tahoe).
/// Falls back with an unsupported-provider error on earlier OS versions so the application can gracefully degrade.
class NativeAppleTranscriptionService: TranscriptionService {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "NativeAppleTranscriptionService")
    
    /// Maps simple language codes to Apple's BCP-47 locale format
    private func mapToAppleLocale(_ simpleCode: String) -> String {
        let mapping = [
            "en": "en-US",
            "es": "es-ES", 
            "fr": "fr-FR",
            "de": "de-DE"
        ]
        return mapping[simpleCode] ?? "en-US"
    }
    
    enum ServiceError: Error, LocalizedError {
        case unsupportedOS
        case transcriptionFailed
        case localeNotSupported
        case invalidModel
        
        var errorDescription: String? {
            switch self {
            case .unsupportedOS:
                return "SpeechAnalyzer requires macOS 26 or later."
            case .transcriptionFailed:
                return "Transcription failed using SpeechAnalyzer."
            case .localeNotSupported:
                return "The selected language is not supported by SpeechAnalyzer."
            case .invalidModel:
                return "Invalid model type provided for Native Apple transcription."
            }
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model is NativeAppleModel else {
            throw ServiceError.invalidModel
        }
        
        // SpeechAnalyzer/SpeechTranscriber is not available in current macOS versions
        logger.error("SpeechAnalyzer requires future macOS version (not available in current OS)")
        throw ServiceError.unsupportedOS
        
        #if canImport(Speech)
        // Note: SpeechAnalyzer/SpeechTranscriber APIs are not available in current macOS versions
        // This code is prepared for future macOS releases
        logger.error("SpeechAnalyzer/SpeechTranscriber APIs are not available in current macOS versions")
        throw ServiceError.unsupportedOS
        #else
        logger.error("Speech framework is not available")
        throw ServiceError.unsupportedOS
        #endif
    }
    
    // Note: This function is commented out as SpeechTranscriber API is not available in current macOS versions
    // @available(macOS 26, *)
    // private func ensureModelIsAvailable(for transcriber: SpeechTranscriber, locale: Locale) async throws {
    //     #if canImport(Speech)
    //     let isInstalled = await SpeechTranscriber.installedLocales.contains(locale)
    //
    //     if !isInstalled {
    //         logger.notice("Assets for '\(locale.identifier)' not installed. Requesting system download.")
    //         
    //         if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    //             try await request.downloadAndInstall()
    //             logger.notice("Asset download for '\(locale.identifier)' complete.")
    //         } else {
    //             logger.error("Asset download for '\(locale.identifier)' failed: Could not create installation request.")
    //             // Note: We don't throw an error here, as transcription might still work with a base model.
    //         }
    //     }
    //     #endif
    // }
} 
