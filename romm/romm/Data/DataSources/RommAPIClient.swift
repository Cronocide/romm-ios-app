//
//  RommAPIClient.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation
import os

protocol RommAPIClientProtocol {
    func makeRequest<T: Codable>(path: String, method: HTTPMethod, body: Data?, responseType: T.Type) async throws -> T
    func makeRequest(path: String, method: HTTPMethod, body: Data?) async throws -> Data
    func get<T: Codable>(_ path: String, responseType: T.Type) async throws -> T
    func get(_ path: String) async throws -> Data
    func post<RequestBody: Codable, ResponseType: Codable>(_ path: String, body: RequestBody, responseType: ResponseType.Type) async throws -> ResponseType
    func post(_ path: String, body: Data?) async throws -> Data
    func put<RequestBody: Codable, ResponseType: Codable>(_ path: String, body: RequestBody, responseType: ResponseType.Type) async throws -> ResponseType
    func put<RequestBody: Codable>(_ path: String, body: RequestBody) async throws -> Data
    func put(_ path: String, body: Data?) async throws -> Data
    func delete(_ path: String) async throws -> Data
    func getRomManual(romId: Int) async throws -> Manual?
    func getManualPDFData(manualURL: String) async throws -> Data
    func getRomDetails(id: Int) async throws -> DetailedRomSchema
    
    // ROM API Wrapper methods
    func getRoms(
        searchTerm: String?,
        platformId: Int?,
        limit: Int
    ) async throws -> CustomLimitOffsetPageSimpleRomSchema
    
    func getRomsWithFilters(
        searchTerm: String?,
        platformId: Int?,
        collectionId: Int?,
        limit: Int,
        offset: Int?,
        withCharIndex: Bool?,
        orderBy: String?,
        orderDir: String?,
        filters: RomFilters
    ) async throws -> CustomLimitOffsetPageSimpleRomSchema
    
    // ROM Search API Wrapper methods
    func searchRomsWithOpenAPI(query: String) async throws -> CustomLimitOffsetPageSimpleRomSchema
    
    // Collections API Wrapper methods
    func getCollections(limit: Int?, offset: Int?) async throws -> [CollectionSchema]
    func getCollection(id: Int) async throws -> CollectionSchema
    func getVirtualCollections(type: String, limit: Int?) async throws -> [VirtualCollectionSchema]
    func getVirtualCollection(id: String) async throws -> VirtualCollectionSchema
    func createCollection(name: String, description: String, isPublic: Bool, artwork: URL?) async throws -> CollectionSchema
    func updateCollection(id: Int, name: String, description: String, isPublic: Bool, romIds: [Int]?, artwork: URL?) async throws -> CollectionSchema
    func deleteCollection(id: Int) async throws -> String
    
    // Platforms API Wrapper methods
    func getPlatforms() async throws -> [PlatformSchema]
    func addPlatform(name: String, slug: String) async throws -> PlatformSchema
    func deletePlatform(id: Int) async throws -> String

    // Heartbeat API Wrapper methods
    func getHeartbeat() async throws -> HeartbeatResponse
    func getHeartbeat(from serverURL: String) async throws -> HeartbeatResponse
}

enum APIClientError: LocalizedError {
    case noConfiguration
    case noCredentials
    case invalidURL(String)
    case authenticationRequired
    case networkError(Error)
    case invalidResponse(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noConfiguration:
            return "No configuration found - please complete setup"
        case .noCredentials:
            return "No authentication credentials found - please setup login"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .authenticationRequired:
            return "Authentication required - please check credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        }
    }
}


class RommAPIClient: RommAPIClientProtocol {
    static let shared = RommAPIClient()

    private let tokenProvider: TokenProviderProtocol
    private let urlSession: URLSession
    private let logger = Logger.network
    private let sessionDelegate = PrivateNetworkURLSessionDelegate()

    // Cache for configuration to avoid repeated setup
    private var cachedBaseURL: String?
    private var cachedUsername: String?
    private var cachedPassword: String?
    private var isConfigured = false

    init(tokenProvider: TokenProviderProtocol = TokenProvider(),
         urlSession: URLSession? = nil) {
        self.tokenProvider = tokenProvider

        // Create URLSession with custom delegate that accepts self-signed certificates
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30.0
            configuration.timeoutIntervalForResource = 60.0
            // Optimized network settings for VPN and local network connections
            configuration.waitsForConnectivity = true
            configuration.allowsCellularAccess = true
            configuration.allowsExpensiveNetworkAccess = true
            configuration.allowsConstrainedNetworkAccess = true
            self.urlSession = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
        }

        setupAPIConfiguration()
    }
    
    private func setupAPIConfiguration() {
        // Get current values
        let currentBaseURL = tokenProvider.getServerURL()
        let currentUsername = tokenProvider.getUsername()
        let currentPassword = tokenProvider.getPassword()
        
        // Check if configuration has changed or if this is first setup
        let hasChanged = currentBaseURL != cachedBaseURL ||
                       currentUsername != cachedUsername ||
                       currentPassword != cachedPassword ||
                       !isConfigured
        
        guard hasChanged else {
            // Configuration unchanged, skip setup
            return
        }
        
        logger.debug("🔄 API configuration changed, updating...")
        
        // Update base URL if available and changed
        if let baseURL = currentBaseURL {
            rommAPI.basePath = baseURL
            logger.debug("✅ OpenAPI base URL updated: \(baseURL)")
        } else {
            logger.warning("⚠️ No server URL available for OpenAPI clients")
        }
        
        // Setup authentication if credentials are available
        if let username = currentUsername, let password = currentPassword {
            // Create Basic Auth header
            let loginString = "\(username):\(password)"
            if let loginData = loginString.data(using: .utf8) {
                let base64LoginString = loginData.base64EncodedString()

                // Set authentication headers for OpenAPI clients
                rommAPI.customHeaders["Authorization"] = "Basic \(base64LoginString)"

                logger.debug("✅ OpenAPI authentication updated for user: \(username)")
            } else {
                logger.error("❌ Failed to encode login data")
            }
        } else {
            logger.warning("⚠️ No authentication credentials available for OpenAPI clients")
        }
        
        // Update cache
        cachedBaseURL = currentBaseURL
        cachedUsername = currentUsername
        cachedPassword = currentPassword
        isConfigured = true
    }
    
    // Force refresh of configuration (useful after login/logout)
    func invalidateConfiguration() {
        logger.debug("🔄 Configuration cache invalidated")
        cachedBaseURL = nil
        cachedUsername = nil
        cachedPassword = nil
        isConfigured = false
        setupAPIConfiguration()
    }
    
    
    // MARK: - New Async/Await API Methods
    
    func makeRequest<T: Codable>(path: String, method: HTTPMethod, body: Data? = nil, responseType: T.Type) async throws -> T {
        let data = try await makeRequest(path: path, method: method, body: body)
        
        do {
            let decodedResponse = try JSONDecoder().decode(responseType, from: data)
            return decodedResponse
        } catch {
            // Log more details about the failed decoding
            let responsePreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
            logger.error("Decoding error for \(responseType) at path \(path): \(error)")
            logger.error("Response data preview: \(responsePreview)")
            throw APIClientError.decodingError(error)
        }
    }
    
    func makeRequest(path: String, method: HTTPMethod, body: Data? = nil) async throws -> Data {
        let measurement = PerformanceMeasurement(operation: "\(method.rawValue) \(path)")
        logger.logNetworkRequest(method: method.rawValue, url: path)

        // Update configuration from token provider (optimized - only when needed)
        // This call is now very cheap due to early-exit caching in setupAPIConfiguration
        setupAPIConfiguration()

        // Build full URL
        let url = try buildURL(path: path)
        
        // Get credentials for Basic Auth
        guard let username = tokenProvider.getUsername(),
              let password = tokenProvider.getPassword() else {
            logger.error("No authentication credentials available")
            throw APIClientError.noCredentials
        }

        // Create Basic Auth header
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            logger.error("Failed to encode credentials")
            throw APIClientError.authenticationRequired
        }
        let base64LoginString = loginData.base64EncodedString()
        
        // Create authenticated request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        if let body = body {
            request.httpBody = body
            logger.debug("Request body size: \(body.count) bytes")
        }
        
        logger.debug("Request URL: \(url.absoluteString)")
        logger.debug("Using Basic Auth for user: \(username)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw APIClientError.networkError(URLError(.badServerResponse))
            }
            
            logger.logNetworkRequest(method: method.rawValue, url: path, statusCode: httpResponse.statusCode)
            logger.debug("Response data size: \(data.count) bytes")
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                measurement.end()
                return data
                
            case 401:
                logger.warning("Authentication failed - invalid credentials")
                // Post notification to trigger automatic logout on session expiration
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw APIClientError.authenticationRequired
                
            case 400...499:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Client error"
                logger.error("Client error (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
                
            case 500...599:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                logger.error("Server error (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
                
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Unexpected status (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
            }
            
        } catch let error as URLError {
            logger.logNetworkError(method: method.rawValue, url: path, error: error)
            throw APIClientError.networkError(error)
        } catch let error as APIClientError {
            // Re-throw APIClientError as is
            throw error
        } catch {
            logger.logNetworkError(method: method.rawValue, url: path, error: error)
            throw APIClientError.networkError(error)
        }
    }
    
    private func buildURL(path: String) throws -> URL {
        guard let serverURL = tokenProvider.getServerURL() else {
            logger.error("No server URL configured")
            throw APIClientError.noConfiguration
        }
        
        // Clean up path and server URL
        let cleanServerURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        let fullURLString = "\(cleanServerURL)/\(cleanPath)"
        
        guard let url = URL(string: fullURLString) else {
            logger.error("Invalid URL: \(fullURLString)")
            throw APIClientError.invalidURL(fullURLString)
        }
        
        return url
    }
    
    // MARK: - Convenience Extensions
    
    func get<T: Codable>(_ path: String, responseType: T.Type) async throws -> T {
        return try await makeRequest(path: path, method: .get, responseType: responseType)
    }
    
    func get(_ path: String) async throws -> Data {
        return try await makeRequest(path: path, method: .get)
    }
    
    func post<RequestBody: Codable, ResponseType: Codable>(
        _ path: String,
        body: RequestBody,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        let jsonData = try JSONEncoder().encode(body)
        return try await makeRequest(path: path, method: .post, body: jsonData, responseType: responseType)
    }
    
    func post(_ path: String, body: Data? = nil) async throws -> Data {
        return try await makeRequest(path: path, method: .post, body: body)
    }
    
    func put<RequestBody: Codable, ResponseType: Codable>(_ path: String, body: RequestBody, responseType: ResponseType.Type) async throws -> ResponseType {
        let jsonData = try JSONEncoder().encode(body)
        return try await makeRequest(path: path, method: .put, body: jsonData, responseType: responseType)
    }
    
    func put<RequestBody: Codable>(_ path: String, body: RequestBody) async throws -> Data {
        let jsonData = try JSONEncoder().encode(body)
        return try await makeRequest(path: path, method: .put, body: jsonData)
    }
    
    func put(_ path: String, body: Data? = nil) async throws -> Data {
        return try await makeRequest(path: path, method: .put, body: body)
    }
    
    func delete(_ path: String) async throws -> Data {
        return try await makeRequest(path: path, method: .delete)
    }
}

// MARK: - Auth API Wrapper
extension RommAPIClient {
    func login() async throws -> String {
        return try await AuthAPI.loginApiLoginPost()
    }
    
    func logout() async throws -> String {
        return try await AuthAPI.logoutApiLogoutPost()
    }
}

// MARK: - Users API Wrapper
extension RommAPIClient {
    func getCurrentUser() async throws -> UserSchema {
        return try await UsersAPI.getCurrentUserApiUsersMeGet()
    }
    
    func getUsers() async throws -> [UserSchema] {
        return try await UsersAPI.getUsersApiUsersGet()
    }
}

// MARK: - ROMs API Wrapper
extension RommAPIClient {
    // Keep the simple version for backward compatibility
    func getRoms(
        searchTerm: String? = nil,
        platformId: Int? = nil,
        limit: Int = 50
    ) async throws -> CustomLimitOffsetPageSimpleRomSchema {
        return try await RomsAPI.getRomsApiRomsGet(
            searchTerm: searchTerm,
            platformId: platformId,
            limit: limit
        )
    }
    
    // Clean version with RomFilters object
    func getRomsWithFilters(
        searchTerm: String? = nil,
        platformId: Int? = nil,
        collectionId: Int? = nil,
        limit: Int = 50,
        offset: Int? = nil,
        withCharIndex: Bool? = nil,
        orderBy: String? = nil,
        orderDir: String? = nil,
        filters: RomFilters
    ) async throws -> CustomLimitOffsetPageSimpleRomSchema {
        // Avoid cross-platform merges when a concrete platform is requested.
        let shouldGroupByMetaId = platformId == nil

        return try await RomsAPI.getRomsApiRomsGet(
            withCharIndex: withCharIndex,
            searchTerm: searchTerm,
            platformId: platformId,
            collectionId: collectionId,
            matched: filters.matched,
            favourite: filters.favourite,
            duplicate: filters.duplicate,
            playable: filters.playable,
            missing: filters.missing,
            hasRa: filters.hasRa,
            verified: filters.verified,
            groupByMetaId: shouldGroupByMetaId,
            selectedGenre: filters.selectedGenre,
            selectedFranchise: filters.selectedFranchise,
            selectedCollection: filters.selectedCollection,
            selectedCompany: filters.selectedCompany,
            selectedAgeRating: filters.selectedAgeRating,
            selectedStatus: filters.selectedStatus,
            selectedRegion: filters.selectedRegion,
            selectedLanguage: filters.selectedLanguage,
            orderBy: orderBy,
            orderDir: orderDir,
            limit: limit,
            offset: offset
        )
    }
    
    func getRomDetails(id: Int) async throws -> DetailedRomSchema {
        return try await RomsAPI.getRomApiRomsIdGet(id: id)
    }
    
    func searchRomsWithOpenAPI(query: String) async throws -> CustomLimitOffsetPageSimpleRomSchema {
        setupAPIConfiguration()
        logger.info("🔍 OpenAPI Search: Searching for '\(query)'")
        let result = try await RomsAPI.getRomsApiRomsGet(
            searchTerm: query,
            limit: 50,
            offset: 0
        )
        logger.info("🔍 OpenAPI Search: Found \(result.items.count) ROMs out of \(result.total ?? 0) total")
        return result
    }
    
    func updateRomFavorite(
        id: Int,
        isFavorite: Bool
    ) async throws -> RomUserSchema {
        // NOTE: The API schema has changed, this method may need to be updated
        // For now, we'll update the last played date instead
        let updateBody = BodyUpdateRomUserApiRomsIdPropsPut(
            updateLastPlayed: true,
            removeLastPlayed: false
        )
        
        return try await RomsAPI.updateRomUserApiRomsIdPropsPut(
            id: id,
            bodyUpdateRomUserApiRomsIdPropsPut: updateBody
        )
    }
    
    func getRomManual(romId: Int) async throws -> Manual? {
        // First get the ROM details to check if manual path exists
        let romDetails = try await get("api/roms/\(romId)", responseType: DetailedRomSchema.self)
        
        // Check if manual path exists in ROM details
        guard let pathManual = romDetails.pathManual, !pathManual.isEmpty else {
            return nil
        }
        
        // Build full URL with server base URL + manual path
        guard let serverURL = tokenProvider.getServerURL() else {
            throw APIClientError.noConfiguration
        }
        
        // Add the missing assets/romm/resources prefix to pathManual
        let completePath = "assets/romm/resources/\(pathManual.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        let fullManualURL = "\(serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(completePath)"
        
        logger.debug("ROM Details pathManual: \(pathManual)")
        logger.debug("Full manual URL: \(fullManualURL)")
        
        let manual = Manual(
            id: 0,
            romId: romId,
            title: "Manual",
            url: fullManualURL,
            fileName: "manual.pdf",
            sizeBytes: nil
        )
        
        return manual
    }
    
    func getManualPDFData(manualURL: String) async throws -> Data {
        // Download PDF from the manual URL with authentication
        guard let url = URL(string: manualURL) else {
            throw APIClientError.invalidURL(manualURL)
        }
        
        // First, we need to authenticate and get session cookies
        // For now, we'll try the direct approach and log what we get
        
        // Create simple request without authentication (since PDF is publicly accessible)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60.0
        
        logger.debug("Attempting PDF download from: \(manualURL)")
        logger.debug("PDF URL for testing: \(manualURL)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.networkError(URLError(.badServerResponse))
            }
            
            logger.debug("PDF Response status: \(httpResponse.statusCode)")
            logger.debug("PDF Response headers: \(httpResponse.allHeaderFields)")
            logger.debug("PDF Data size: \(data.count) bytes")
            
            // Log first few bytes to see what we actually got
            let preview = data.prefix(20)
            let previewString = String(data: preview, encoding: .utf8) ?? "Binary data"
            logger.debug("PDF Data preview: \(previewString)")
            
            switch httpResponse.statusCode {
            case 200...299:
                // Check if we got HTML instead of PDF
                if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                    logger.debug("Content-Type: \(contentType)")
                    if contentType.contains("text/html") {
                        let htmlContent = String(data: data, encoding: .utf8) ?? "HTML content"
                        logger.error("Received HTML instead of PDF: \(htmlContent.prefix(200))")
                        throw APIClientError.invalidResponse(200, "Received HTML instead of PDF - authentication may have failed")
                    }
                }
                return data
            case 401, 403:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Authentication failed"
                logger.warning("Authentication failed: \(errorMessage)")
                throw APIClientError.authenticationRequired
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "PDF download failed"
                logger.error("PDF download failed (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
            }
            
        } catch let error as URLError {
            logger.logNetworkError(method: "GET", url: manualURL, error: error)
            throw APIClientError.networkError(error)
        } catch let error as APIClientError {
            throw error
        } catch {
            logger.error("Unexpected error during PDF download: \(error)")
            throw APIClientError.networkError(error)
        }
    }
}

// MARK: - Collections API Wrapper
extension RommAPIClient {
    func getCollections(limit: Int? = nil, offset: Int? = nil) async throws -> [CollectionSchema] {
        setupAPIConfiguration()
        return try await CollectionsAPI.getCollectionsApiCollectionsGet()
    }
    
    func getCollection(id: Int) async throws -> CollectionSchema {
        setupAPIConfiguration()
        return try await CollectionsAPI.getCollectionApiCollectionsIdGet(id: id)
    }
    
    func getVirtualCollections(type: String, limit: Int? = nil) async throws -> [VirtualCollectionSchema] {
        setupAPIConfiguration()
        return try await CollectionsAPI.getVirtualCollectionsApiCollectionsVirtualGet(type: type, limit: limit)
    }
    
    func getVirtualCollection(id: String) async throws -> VirtualCollectionSchema {
        setupAPIConfiguration()
        return try await CollectionsAPI.getVirtualCollectionApiCollectionsVirtualIdGet(id: id)
    }
    
    func createCollection(artwork: URL? = nil) async throws -> CollectionSchema {
        setupAPIConfiguration()
        return try await CollectionsAPI.addCollectionApiCollectionsPost(artwork: artwork)
    }
    
    func createCollection(
        name: String,
        description: String,
        isPublic: Bool,
        artwork: URL? = nil
    ) async throws -> CollectionSchema {
        logger.info("🚀 Creating collection - name: '\(name)', description: '\(description)', isPublic: \(isPublic)")
        
        return try await createOrUpdateCollection(
            method: "POST",
            path: "api/collections",
            name: name,
            description: description,
            romIds: nil, // New collections start empty
            artwork: artwork
        )
    }
    
    func updateCollection(
        id: Int,
        name: String,
        description: String,
        isPublic: Bool,
        romIds: [Int]? = nil,
        artwork: URL? = nil
    ) async throws -> CollectionSchema {
        logger.info("🔄 Updating collection \(id) - name: '\(name)', description: '\(description)', romIds: \(romIds?.count ?? 0)")
        
        // Use the same multipart implementation as createCollection, but with PUT method
        return try await createOrUpdateCollection(
            method: "PUT",
            path: "api/collections/\(id)?is_public=\(isPublic)&remove_cover=false",
            name: name,
            description: description,
            romIds: romIds,
            artwork: artwork
        )
    }
    
    func deleteCollection(id: Int) async throws -> String {
        setupAPIConfiguration()
        return try await CollectionsAPI.deleteCollectionApiCollectionsIdDelete(id: id)
    }
    
    // MARK: - Private Helper for Collection Operations
    
    private func createOrUpdateCollection(
        method: String,
        path: String,
        name: String,
        description: String,
        romIds: [Int]? = nil,
        artwork: URL? = nil
    ) async throws -> CollectionSchema {
        // Get server configuration manually
        guard let serverURL = tokenProvider.getServerURL()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            logger.error("Missing server configuration")
            throw APIClientError.noConfiguration
        }
        
        // Get username and password for Basic Auth (Collection API needs real Basic Auth, not JWT)
        guard let username = tokenProvider.getUsername(),
              let password = tokenProvider.getPassword() else {
            logger.error("Missing username or password for Basic Auth")
            throw APIClientError.noCredentials
        }

        // Create Basic Auth token: username:password -> Base64
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            logger.error("Failed to encode credentials")
            throw APIClientError.noCredentials
        }
        let basicAuthToken = loginData.base64EncodedString()
        
        // Create full URL manually
        let cleanServerURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullURL = "\(cleanServerURL)/\(path)"
        
        guard let url = URL(string: fullURL) else {
            logger.error("Invalid URL: \(fullURL)")
            throw APIClientError.invalidURL(fullURL)
        }
        
        // Create multipart form data exactly like Safari browser
        let boundaryId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let boundary = "WebKitFormBoundary\(boundaryId)"
        var formData = Data()
        
        // Add name field
        formData.append("------\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(name)\r\n".data(using: .utf8)!)
        
        // Add description field (can be empty)
        formData.append("------\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        if !description.isEmpty {
            formData.append("\(description)\r\n".data(using: .utf8)!)
        } else {
            formData.append("\r\n".data(using: .utf8)!)
        }
        
        // Add url_cover field (empty for now)
        formData.append("------\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"url_cover\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\r\n".data(using: .utf8)!)
        
        // Add rom_ids field
        formData.append("------\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"rom_ids\"\r\n\r\n".data(using: .utf8)!)
        if let romIds = romIds, !romIds.isEmpty {
            let romIdsJson = "[\(romIds.map(String.init).joined(separator: ","))]"
            formData.append("\(romIdsJson)\r\n".data(using: .utf8)!)
        } else {
            formData.append("undefined\r\n".data(using: .utf8)!)
        }
        
        // Close the form data
        formData.append("------\(boundary)--\r\n".data(using: .utf8)!)
        
        logger.debug("📝 \(method) request URL: \(fullURL)")
        logger.debug("📝 ROM IDs: \(romIds?.description ?? "nil")")
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=----\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(basicAuthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(cleanServerURL, forHTTPHeaderField: "Origin")
        request.setValue("\(cleanServerURL)/", forHTTPHeaderField: "Referer")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        
        request.httpBody = formData
        
        // Perform the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.networkError(NSError(domain: "InvalidResponse", code: 0))
            }
            
            logger.info("📡 \(method) response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server error (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIClientError.invalidResponse(httpResponse.statusCode, errorMessage)
            }
            
            let decodedCollection = try JSONDecoder().decode(CollectionSchema.self, from: data)
            logger.info("✅ Collection \(method.lowercased()) successful: id=\(decodedCollection.id), name='\(decodedCollection.name)'")
            
            return decodedCollection
            
        } catch let urlError as URLError {
            throw APIClientError.networkError(urlError)
        } catch let decodingError as DecodingError {
            throw APIClientError.decodingError(decodingError)
        } catch let apiError as APIClientError {
            throw apiError
        } catch {
            throw APIClientError.networkError(error)
        }
    }
    
    func updateCollection(
        id: Int,
        removeCover: Bool? = nil,
        isPublic: Bool? = nil,
        artwork: URL? = nil
    ) async throws -> CollectionSchema {
        setupAPIConfiguration()
        return try await CollectionsAPI.updateCollectionApiCollectionsIdPut(
            id: id,
            removeCover: removeCover,
            isPublic: isPublic,
            artwork: artwork
        )
    }
}

// MARK: - Platforms API Wrapper
extension RommAPIClient {
    func getPlatforms() async throws -> [PlatformSchema] {
        setupAPIConfiguration()
        return try await PlatformsAPI.getPlatformsApiPlatformsGet()
    }
    
    func addPlatform(
        name: String,
        slug: String
    ) async throws -> PlatformSchema {
        setupAPIConfiguration()
        let platformBody = BodyAddPlatformApiPlatformsPost(fsSlug: slug)
        return try await PlatformsAPI.addPlatformApiPlatformsPost(
            bodyAddPlatformApiPlatformsPost: platformBody
        )
    }
    
    func deletePlatform(id: Int) async throws -> String {
        setupAPIConfiguration()
        return try await PlatformsAPI.deletePlatformApiPlatformsIdDelete(id: id)
    }
}

// MARK: - Heartbeat API Wrapper
extension RommAPIClient {
    func getHeartbeat() async throws -> HeartbeatResponse {
        setupAPIConfiguration()
        return try await SystemAPI.heartbeatApiHeartbeatGet()
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
