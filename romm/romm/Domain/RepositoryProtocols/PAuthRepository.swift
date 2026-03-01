//
//  PAuthRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

protocol PAuthRepository {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    func login(username: String, password: String) async throws -> User
    func logout() async throws
    func getCurrentUser() async throws -> User?
}