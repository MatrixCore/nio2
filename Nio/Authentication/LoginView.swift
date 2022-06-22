//
//  LoginView.swift
//  Nio
//
//  Created by Finn Behrens on 21.06.22.
//

import SwiftUI
import MatrixClient
import MatrixCore

struct LoginView: View {
    @State var username: String = ""
    @State var password: String = ""
    @State var useUsername: Bool = true
    @State var serverChanged: Bool = true
    @State var homeserver: MatrixHomeserver?
    @State var flows: [MatrixLoginFlow]?
    
    var body: some View {
        TextField(useUsername ? "Username" : "Homeserver", text: $username)
            .textContentType(useUsername ? .username : nil)
            .textFieldStyle(.roundedBorder)
            .modifier(TextFieldNextButton(text: $username, showButton: $serverChanged, callback: self.discoverServer))
            .multilineTextAlignment(.leading)
            .submitLabel(.next)
            .onSubmit(self.discoverServer)
            /*.onChange(of: username, perform: {
                flows = nil
            })*/
        
        if flows?.contains(where: { $0.type == .password}) ?? false {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .modifier(TextFieldNextButton(text: $password, callback: { print("login") }))
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
        }
        
        if let IPs = flows?.first(where: { $0.type == .sso })?.identiyProviders {
            LoginSSOListView(identityProviders: IPs)
        }
    }
    
    func discoverServer() {
        Task {
            do {
                try await self.discoverServerThrowing()
            } catch {
                print(error)
            }
        }
    }
    
    func discoverServerThrowing() async throws {
        if useUsername {
            guard let mxID = MatrixFullUserIdentifier(string: username) else {
                throw MatrixCommonErrorCode.invalidUserName
            }
            
            homeserver = try await .init(resolve: mxID)
        } else {
            fatalError("TODO")
        }
        
        let client = MatrixClient(homeserver: homeserver!)
        
        flows = try await client.getLoginFlows()
    }
}

struct TextFieldNextButton: ViewModifier {
    @Binding var text: String
    @Binding var showButton: Bool
    var callback: () -> Void
    
    init(text: Binding<String>, showButton: Binding<Bool> = .constant(true), callback: @escaping () -> Void) {
        self._text = text
        self._showButton = showButton
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
            LoginView()
            
            LoginView(username: "test")
        }
    }
}
