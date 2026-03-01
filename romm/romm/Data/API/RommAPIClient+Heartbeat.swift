//
//  RommAPIClient+Heartbeat.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

// MARK: - Heartbeat API Wrapper
extension RommAPIClient {
    func getHeartbeat() async throws -> HeartbeatResponse {
        return try await get("api/heartbeat", responseType: HeartbeatResponse.self)
    }

    /// Get heartbeat from a specific server URL (for setup flow before login)
    func getHeartbeat(from serverURL: String) async throws -> HeartbeatResponse {
        let cleanURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanURL)/api/heartbeat") else {
            throw APIClientError.invalidURL("\(cleanURL)/api/heartbeat")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0

        logger.debug("Fetching heartbeat from: \(url.absoluteString)")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
        }

        return try JSONDecoder().decode(HeartbeatResponse.self, from: data)
    }
}