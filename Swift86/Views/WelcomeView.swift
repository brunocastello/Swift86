//
//  WelcomeView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Welcome View

// Initial welcome view
struct WelcomeView: View {
    
    // MARK: - Environment Objects
    
    // Environment object machine library
    @EnvironmentObject var library: Library
    
    // MARK: - Scene
    
    var body: some View {
        VStack {
            // Welcome message
            Text("Welcome to Swift86")
                .font(.system(size: 20, weight: .medium))
                .padding(.bottom, 2)
            Text("Select or add a machine.")
                .font(.title3)
                .foregroundColor(.secondary)

            HStack {
                // Add a new machine
                Button(action: {
                    library.newMachine = Machine()
                }) {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 48))
                            .padding(.bottom, 8)
                        Text("New Machine")
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 150, maxHeight: 150, alignment: .center)
                }
                .buttonStyle(WelcomeButtonStyle())
                
                // 86Box Documentation
                Button(action: {
                    let url = URL(string: WebLinks.support.rawValue)!
                    NSWorkspace.shared.open(url)
                }) {
                    VStack {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .padding(.bottom, 8)
                        Text("Documentation")
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 150, maxHeight: 150, alignment: .center)
                }
                .buttonStyle(WelcomeButtonStyle())

                // 86Box Discord
                Button(action: {
                    let url = URL(string: WebLinks.discord.rawValue)!
                    NSWorkspace.shared.open(url)
                }) {
                    VStack {
                        Image(systemName: "ellipsis.message")
                            .font(.system(size: 48))
                            .padding(.bottom, 8)
                        Text("86Box Discord")
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 150, maxHeight: 150, alignment: .center)
                }
                .buttonStyle(WelcomeButtonStyle())
            }
            .padding()
        }
    }
}

// MARK: - Preview

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
