//
//  ContentView.swift
//  Nio
//
//  Created by Finn Behrens on 08.06.22.
//

import SwiftUI

struct ContentView: View {
    @State var showLogin = true
    
    var body: some View {
        VStack {
            LoginView(isPresent: $showLogin)
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
