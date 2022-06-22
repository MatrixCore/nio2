//
//  LoginSSOView.swift
//  Nio
//
//  Created by Finn Behrens on 22.06.22.
//

import SwiftUI
import MatrixClient

struct LoginSSOView: View {
    var provider: MatrixLoginFlow.IdentityProvider
    
    var body: some View {
        switch provider.brand {
        case .some(.apple):
            Label("Sign in with Apple", systemImage: "applelogo")
        case .some(.facebook):
            Label() {
                Text("Facebook")
            } icon: {
                Image("Branding/Facebok")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
        case .some(.github):
            Label() {
                Text("GitHub")
            } icon: {
                Image("Branding/GitHub")
                    .resizable()
                    .padding(.all, 1)
                    .frame(width: 20, height: 20)
            }
        case .some(.gitlab):
            Label() {
                Text("Gitlab")
            } icon: {
                Image("Branding/Gitlab")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
        case .some(.google):
            Label() {
                Text("google")
            } icon: {
                Image("Branding/Google")
                    .resizable()
                    .frame(height: 25)
            }
        default:
            LoginSSOGenericView(provider: provider)
        }
    }
}

struct LoginSSOGenericView: View {
    var provider: MatrixLoginFlow.IdentityProvider
    
    var body: some View {
        Label(title: { Text(provider.name) }) {
            if let url = provider.icon?.downloadURL() {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .padding(.all, 1)
                } placeholder: {
                    Text("foo")
                }
                .frame(width: 20, height: 20)
            } else {
                Text(provider.icon?.downloadURL()?.absoluteString ?? "icon")
            }
        }
    }
}

struct LoginSSOListView: View {
    var identityProviders: [MatrixLoginFlow.IdentityProvider]
    
    var body: some View {
        List(identityProviders) { provider in
            LoginSSOView(provider: provider)
        }
    }
}

struct LoginSSOView_Previews: PreviewProvider {
    static var previews: some View {
        LoginSSOListView(identityProviders: [
            .init(brand: .apple, id: "apple", name: "apple"),
            .init(brand: .facebook, id: "facebook", name: "facebook"),
            .init(brand: .github, id: "github", name: "gitub"),
            .init(brand: .gitlab, id: "gitlab", name: "gitlab"),
            .init(brand: .google, id: "google", name: "google"),
            .init(brand: .twitter, id: "twitter", name: "twitter")
            //.init(icon: MatrixContentURL(string: "mxc://matrix.org/MCVOEmFgVieKFshPxmnejWOq"), id: "gitlab", name: "gitlab")
        ])
    }
}
