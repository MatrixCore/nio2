//
//  AccountManager.swift
//  NioKit
//
//  Created by Finn Behrens on 21.06.22.
//

import Foundation
import MatrixClient
import MatrixCore
import MatrixCDStore
import CoreData
import OSLog

public typealias Store = MatrixCDStore

@MainActor
public class NioAccountManager: ObservableObject {
    public static let logger = Logger(subsystem: "chat.nio.kit", category: "AccountManager")
    
    public static let shared = NioAccountManager(store: Store.shared)
    #if DEBUG
    public static let preview = NioAccountManager(store: Store.preview)
    #endif
    
    
    public let store: Store
    public var viewContext: NSManagedObjectContext {
        store.viewContext
    }
    
    public var extraKeychainParameters: [String: Any] {
        MatrixCDStore.extraKeychainArguments
    }
   
    private init(store: Store) {
        self.store = store
        
        Task(priority: .userInitiated) {
            do {
                try await self.updateAccounts()
            } catch {
                Self.logger.error("Failed to load accounts: \(error.localizedDescription)")
            }
        }
    }

    internal func updateAccounts() async throws {
        let accounts = try await store.getAccountInfos()
        print(try accounts.first?.getFromKeychain())
    }
    
    
    public func addAccount(_ login: MatrixLogin) async throws {
        Self.logger.debug("Saving account: \(login.userId?.localpart ?? "???")")
        guard let userId = login.userId,
              let baseUrl = login.wellKnown?.homeserver?.baseURL,
              let hs = MatrixHomeserver(string: baseUrl),
              let deviceId = login.deviceId,
              let accessToken = login.accessToken
        else {
            throw MatrixCommonErrorCode.missingParam
        }
        
        let account = try await self.store.saveAccountInfo(userId, name: userId.localpart, homeServer: hs, deviceId: deviceId, accessToken: accessToken)
    }
}
