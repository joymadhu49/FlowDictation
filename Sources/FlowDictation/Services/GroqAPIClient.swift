import Foundation

class GroqAPIClient {
    private let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let model = "whisper-large-v3-turbo"

    struct TranscriptionResponse: Codable {
        let text: String
    }

    struct APIErrorResponse: Codable {
        let error: APIErrorDetail?
    }

    struct APIErrorDetail: Codable {
        let message: String?
        let type: String?
    }

    // MARK: - Transcription

    func transcribe(audioFileURL: URL, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqAPIError.missingAPIKey
        }

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw GroqAPIError.audioFileNotFound
        }

        let audioData = try Data(contentsOf: audioFileURL)

        // Check file size (Groq limit is 25MB)
        let fileSizeMB = Double(audioData.count) / (1024 * 1024)
        if fileSizeMB > 25 {
            throw GroqAPIError.fileTooLarge
        }

        guard let url = URL(string: baseURL) else {
            throw GroqAPIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build multipart body
        var body = Data()

        // Add model field
        body.appendMultipartField(name: "model", value: model, boundary: boundary)

        // Add response_format field
        body.appendMultipartField(name: "response_format", value: "json", boundary: boundary)

        // Add language field (optional, helps accuracy)
        body.appendMultipartField(name: "language", value: "en", boundary: boundary)

        // Add audio file
        let filename = audioFileURL.lastPathComponent
        let mimeType = "audio/wav"
        body.appendMultipartFile(name: "file", filename: filename, mimeType: mimeType, data: audioData, boundary: boundary)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let transcription = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                throw GroqAPIError.emptyTranscription
            }
            return text

        case 401:
            throw GroqAPIError.unauthorized

        case 413:
            throw GroqAPIError.fileTooLarge

        case 429:
            throw GroqAPIError.rateLimited

        default:
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               let message = errorResponse.error?.message {
                throw GroqAPIError.serverError(httpResponse.statusCode, message)
            }
            throw GroqAPIError.serverError(httpResponse.statusCode, "Unknown error")
        }
    }
}

// MARK: - Errors

enum GroqAPIError: LocalizedError {
    case missingAPIKey
    case audioFileNotFound
    case fileTooLarge
    case invalidURL
    case invalidResponse
    case emptyTranscription
    case unauthorized
    case rateLimited
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Groq API key not set. Open settings to enter your API key."
        case .audioFileNotFound:
            return "Audio recording file not found."
        case .fileTooLarge:
            return "Audio file exceeds 25MB limit."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from Groq API."
        case .emptyTranscription:
            return "No speech detected in the recording."
        case .unauthorized:
            return "Invalid Groq API key. Check your API key in settings."
        case .rateLimited:
            return "Rate limited by Groq API. Please wait a moment."
        case .serverError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}

// MARK: - Data Extensions for Multipart

extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        let fieldData = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
        self.append(fieldData.data(using: .utf8)!)
    }

    mutating func appendMultipartFile(name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        var fieldData = "--\(boundary)\r\n"
        fieldData += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        fieldData += "Content-Type: \(mimeType)\r\n\r\n"
        self.append(fieldData.data(using: .utf8)!)
        self.append(data)
        self.append("\r\n".data(using: .utf8)!)
    }
}
