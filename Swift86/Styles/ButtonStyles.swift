//
//  ButtonStyles.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Colors

extension Color {
    // Subtle fill that stands out from the window/content background in light and dark mode
    static let tileBackground = Color.primary.opacity(0.075)
}

// MARK: - Panel Style
struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Panel spacing and width
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Panel fill
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.tileBackground.opacity(0.5))
            )
            // Panel border
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    // Bordered rounded panel
    func panelStyle() -> some View {
        modifier(PanelStyle())
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
                .background(Color.tileBackground)
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
                .background(isHovering ? Color.tileBackground : .clear)
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
