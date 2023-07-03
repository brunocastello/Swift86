//
//  ButtonStyles.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Standard Button Style

// Standard button style
struct ButtonStandardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 60)
    }
}

// Extension for standard button style
extension Text {
    func standardStyle() -> some View {
        self.modifier(ButtonStandardStyle())
    }
}

// MARK: - Welcome View Button Style

// Welcome button style
struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonView(configuration: configuration)
    }

    struct ButtonView: View {
        let configuration: Configuration

        // Button style
        var body: some View {
            configuration.label
                .fontWeight(.medium)
                .background(Color(NSColor.windowBackgroundColor))
                .foregroundColor(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Machine View Button Style

// Machine view button style
struct MachineButtonStyle: ButtonStyle {
    var isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        ButtonView(configuration: configuration, isDisabled: isDisabled)
    }

    struct ButtonView: View {
        let configuration: Configuration
        let isDisabled: Bool

        // Button hover state
        @State private var isHovering = false

        // Button style
        var body: some View {
            configuration.label
                .fontWeight(.bold)
                .frame(maxWidth: 38, maxHeight: 38)
                .background(isHovering ? Color(NSColor.windowBackgroundColor) : .clear)
                .foregroundColor(configuration.isPressed ? .primary : (isHovering ? .accentColor : .gray))
                .opacity(configuration.isPressed ? 0.5 : (isDisabled ? 0.5 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onHover { hover in
                    isHovering = hover
                }
                .allowsHitTesting(!isDisabled)
        }
    }
}
