//
//  AccountManager.swift
//  NioKit
//
//  Created by Finn Behrens on 21.06.22.
//

import Foundation
import MatrixCore
import MatrixCDStore
import CoreData

public typealias Store = MatrixCDStore

@MainActor
public struct NioAccountManager {
    public static let shared = Self.init(store: Store.shared)
    #if DEBUG
    public static let prevew = Self.init(store: Store.preview)
    #endif
    
    let store: Store
    var viewContext: NSManagedObjectContext {
        store.viewContext
    }
   
    private init(store: Store) {
        self.store = store
    }

}
