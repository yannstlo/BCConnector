import Foundation

enum OpenAIError: Error {
    case missingAPIKey
    case invalidURL
    case httpError(Int)
    case decodingError(String)
}

final class OpenAIClient {
    static let shared = OpenAIClient()
    private init() {}

    private let settings = SettingsManager.shared

    private var apiKey: String? { settings.openAIAPIKey.isEmpty ? nil : settings.openAIAPIKey }
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    // Placeholder transcription request (Whisper). Wire actual multipart body when integrating.
    func transcribe(audioData: Data, fileName: String = "audio.m4a") async throws -> String {
        guard let apiKey = apiKey else { throw OpenAIError.missingAPIKey }
        let url = baseURL.appendingPathComponent("audio/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // TODO: Build multipart/form-data body for Whisper
        request.httpBody = Data()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.httpError(-1) }
        guard (200...299).contains(http.statusCode) else { throw OpenAIError.httpError(http.statusCode) }
        // TODO: Decode JSON for the transcription result
        return String(data: data, encoding: .utf8) ?? ""
    }

    // Placeholder text-to-speech request. Wire actual body when integrating.
    func synthesize(text: String, voice: String = "alloy") async throws -> Data {
        guard let apiKey = apiKey else { throw OpenAIError.missingAPIKey }
        let url = baseURL.appendingPathComponent("audio/speech")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "gpt-4o-mini-tts",
            "voice": voice,
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.httpError(-1) }
        guard (200...299).contains(http.statusCode) else { throw OpenAIError.httpError(http.statusCode) }
        return data
    }
}
