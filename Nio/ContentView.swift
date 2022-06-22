//
//  ContentView.swift
//  Nio
//
//  Created by Finn Behrens on 08.06.22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            LoginView()
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
