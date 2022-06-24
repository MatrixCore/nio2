//
//  LoginView.swift
//  Nio
//
//  Created by Finn Behrens on 21.06.22.
//


import SwiftUI
import MatrixClient
import MatrixCore
import AuthenticationServices
import NioKit
import Security

#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @EnvironmentObject var manager: NioAccountManager
    
    @Binding var isPresent: Bool
    
    @State var username: String = ""
    @State var password: String = ""
    @State var useUsername: Bool = true
    @State var serverChanged: Bool = true
    @State var homeserver: MatrixHomeserver?
    @State var flows: [MatrixLoginFlow]?
    @State var error: Error?
    @State var showSaveQuestion: Bool = false
    
    @ObservedObject var singinViewModel = SignInViewModel()
    
    var body: some View {
        VStack {
            TextField(useUsername ? "Username" : "Homeserver", text: $username)
                .textContentType(useUsername ? .username : nil)
                .textFieldStyle(.roundedBorder)
                .modifier(TextFieldNextButton(text: $username, showButton: flows == nil, callback: self.discoverServer))
                .multilineTextAlignment(.leading)
                .submitLabel(.next)
                .onSubmit(self.discoverServer)
                .onChange(of: username) { _ in
                    flows = nil
                }
            
            if flows?.contains(where: { $0.type == .password}) ?? false {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .modifier(TextFieldNextButton(text: $password, callback: self.login))
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .onSubmit(self.login)
            }
            
            HStack {
                if singinViewModel.isAuthRunning {
                    Button("Cancel SSO", role: .destructive) {
                        singinViewModel.cancel()
                    }
                }
                Spacer(minLength: 0)
                
                Button(flows == nil ? "next" : "Log in") {
                    guard flows != nil else {
                        self.discoverServer()
                        return
                    }
                    
                    self.login()
                }
            }
            
            if let IPs = flows?.first(where: { $0.type == .sso })?.identiyProviders {
                LoginSSOListView(identityProviders: IPs, doSSO: self.loginWithSSO)
            }
        }
        .alert("Save password to keychain", isPresented: $showSaveQuestion, presenting: username) { username in
            Button(role: .destructive) {
                NioAccountManager.logger.info("Saving cleartext password to keychain")
                do {
                    try self.savePasswordToKeychain()
                } catch {
                    NioAccountManager.logger.error("failed to save cleartext password: \(error)")
                    self.error = error
                }
                // TODO: somehow scheduale to first show the error
                isPresent = false
            } label: {
                Text("Save to keychain")
            }
            .keyboardShortcut(.defaultAction)
            
            Button(role: .cancel) {
                isPresent = false
            } label: {
                Text("Don't save")
            }
        } message: { username in
            Text("Save password for \(username) to keychain. This is protected by biometric protection. Look in the FAQ for more informations.")
        }
        .alert("Error", isPresented: .constant(error != nil), presenting: error) { error in
            Button() {
                self.error = nil
            } label: {
                Text("Ok")
            }
        } message: { error in
            Text(error.localizedDescription)
                .foregroundColor(.red)
        }
    }
    
    func loginWithSSO(sso: MatrixLoginFlow.IdentityProvider) -> Void {
        Task {
            do {
                let url = try await singinViewModel.startSSOLogin(homserver: homeserver!, providerId: sso.id)
                
                var urlComponents = URLComponents()
                urlComponents.query = url.query()
                let token = urlComponents.queryItems?.first(where: { $0.name == "loginToken" })?.value
                
                guard let token,
                      let homeserver
                else {
                    throw MatrixCommonErrorCode.invalidParam
                }
                
                let client = MatrixClient(homeserver: homeserver)
                let login = try await client.login(token: true, password: token)
                try await self.login(login)
            } catch {
                NioAccountManager.logger.error("Failed to log in with SSO: \(error)")
                self.error = error
            }
        }
    }
    
    func login() {
        self.login(passwordFromKeychain: false)
    }
    
    func login(passwordFromKeychain: Bool) {
        Task {
            do {
                try await self.login(passwordFromKeychain: passwordFromKeychain)
            } catch {
                NioAccountManager.logger.error("Failed to log in: \(error)")
                self.error = error
            }
        }
    }
    
    func login(passwordFromKeychain: Bool) async throws {
        guard let homeserver else {
            throw MatrixCommonErrorCode.missingParam
        }
        
        let client = MatrixClient(homeserver: homeserver)
        let login = try await client.login(username: username, password: password, displayName: self.buildInitalDisplayName())
        
        if !passwordFromKeychain {
            showSaveQuestion = true
        }
        
        try await self.login(login)
    }
    
    func login(_ login: MatrixLogin) async throws {
        try await manager.addAccount(login)
        print(login)
    }
    
    func discoverServer() {
        self.error = nil
        guard !username.isEmpty else {
            return
        }
        Task {
            do {
                try await self.discoverServerThrowing()
            } catch {
                NioAccountManager.logger.error("Failed to discover server: \(error)")
                self.error = error
            }
        }
    }
    
    func discoverServerThrowing() async throws {
        if useUsername {
            guard let mxID = MatrixFullUserIdentifier(string: username) else {
                throw MatrixCommonErrorCode.invalidUserName
            }
            
            do {
                _ = try await self.manager.store.getAccountInfo(accountID: mxID)
                self.error = MatrixCoreError.missingData // TODO: proper error for account allready logged in
                return
            } catch {
                // pass
            }
            
            homeserver = try await .init(resolve: mxID)
            
            self.loadPasswordFromKeychain()
        } else {
            fatalError("TODO")
        }
        
        let client = MatrixClient(homeserver: homeserver!)
        
        flows = try await client.getLoginFlows()
    }
    
    #if canImport(UIKit)
    func buildInitalDisplayName() -> String {
//        "Nio (\(ProcessInfo.processInfo.hostName))"
        "Nio (\(UIDevice.current.name))"
    }
    #else
    func buildInitalDisplayName() -> String {
        "Nio (macOS)"
    }
    #endif
    
    // MAKR: keychain
    func savePasswordToKeychain() throws {
        let server: String = homeserver!.url.url!.absoluteString
        
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(nil,
                                                     kSecAttrAccessibleWhenUnlocked,
                                                     .userPresence,
                                                     &error
        )
        
        guard error == nil else {
            throw MatrixCoreError.unexpectedError(error: error!.takeRetainedValue() as Error)
        }
        
        var query = manager.extraKeychainParameters
        query[kSecClass as String] = kSecClassInternetPassword
        query[kSecAttrAccount as String] = username
        query[kSecAttrServer as String] = server
        query[kSecAttrLabel as String] = "\(server) (\(username))"
        query[kSecUseDataProtectionKeychain as String] = true
        // Items stored or obtained using the kSecAttrSynchronizable key cannot specify SecAccess-based access control with kSecAttrAccess. If a password is intended to be shared between multiple applications, the kSecAttrAccessGroup key must be specified, and each application using this password must have the Keychain Access Groups Entitlement enabled, and a common access group specified.

        //query[kSecAttrSynchronizable as String] = true
        query[kSecAttrAccessControl as String] = access
        query[kSecValueData as String] = password.data(using: .utf8)!
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MatrixCoreError.keychainError(status)
        }
    }
    
    func loadPasswordFromKeychain() {
        let server: String = homeserver!.url.url!.absoluteString
        
        var query = manager.extraKeychainParameters
        query[kSecClass as String] = kSecClassInternetPassword
        query[kSecAttrAccount as String] = username
        query[kSecAttrServer as String] = server
        query[kSecUseDataProtectionKeychain as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            NioAccountManager.logger.debug("Could not find password: \(status)")
            return
        }
        
        guard let existingItem = item as? [String: Any],
              let tokenData = existingItem[kSecValueData as String] as? Data,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            NioAccountManager.logger.error("Could not parse cleartext password")
            return
        }
        
        self.password = token
        self.login(passwordFromKeychain: true)
    }
}

struct TextFieldNextButton: ViewModifier {
    @Binding var text: String
    var showButton: Bool
    var callback: () -> Void
    
    init(text: Binding<String>, showButton: Bool = true, callback: @escaping () -> Void) {
        self._text = text
        self.showButton = showButton
        self.callback = callback
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if !text.isEmpty && showButton {
                HStack {
                    Spacer(minLength: 0)
                    
                    Button(action: callback, label: {
                        Image(systemName: "arrow.forward.circle")
                            .foregroundColor(.secondary)
                    })
                    .buttonStyle(.plain)
                    .padding(.trailing, 5)
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView(isPresent: .constant(true))
            
            LoginView(isPresent: .constant(true), username: "test", flows: [.init(type: .password)])
        }
    }
}

// MARK: AS implementation class
class SignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var authSession: ASWebAuthenticationSession?
    
    var isAuthRunning: Bool {
        self.authSession != nil
    }
    
    @MainActor
    func startSSOLogin(homserver: MatrixHomeserver, providerId: String) async throws -> URL {
        if self.authSession != nil {
            throw MatrixCommonErrorCode.badState
        }
        
        let ret: URL = try await withCheckedThrowingContinuation { continuation in
            do {
                try self.startSSOLogin(homeserver: homserver, providerId: providerId, callback: { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: MatrixCoreError.missingData)
                    }
                })
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        self.authSession = nil
        return ret
    }
    
    @MainActor
    func cancel() {
        if let authSession {
            authSession.cancel()
            self.authSession = nil
        }
    }
    
    func startSSOLogin(homeserver: MatrixHomeserver, providerId: String, callback: @escaping ASWebAuthenticationSession.CompletionHandler) throws {
        
        var url = homeserver.path("/_matrix/client/v3/login/sso/redirect/\(providerId)")
        url.queryItems = [.init(name: "redirectUrl", value: "nio://login/")]
        guard let url = url.url else {
            throw MatrixCommonErrorCode.invalidParam
        }
                                        
        
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "nio", completionHandler: callback)
        
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
