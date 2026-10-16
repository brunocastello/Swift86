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

// MARK: - Interface Style

// Look of the surfaces Swift86 draws itself: Liquid Glass by default, or the classic flat tiles
enum InterfaceStyle {
    case glass, classic
}

extension EnvironmentValues {
    @Entry var interfaceStyle: InterfaceStyle = .glass
}

// MARK: - Panel Style
struct PanelStyle: ViewModifier {
    @Environment(\.interfaceStyle) private var interfaceStyle

    func body(content: Content) -> some View {
        let padded = content
            // Panel spacing and width
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        switch interfaceStyle {
        case .classic:
            padded
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
        case .glass:
            padded
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Tile Surface

// Rounded tile behind the icon thumbnail in the Edit sheet
struct TileSurface: ViewModifier {
    @Environment(\.interfaceStyle) private var interfaceStyle

    func body(content: Content) -> some View {
        switch interfaceStyle {
        case .classic:
            content
                .background(Color.tileBackground)
                .cornerRadius(8)
        case .glass:
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Window Chrome

// Toolbar background: the classic opaque bar, or the system default
struct ToolbarChrome: ViewModifier {
    @Environment(\.interfaceStyle) private var interfaceStyle

    func body(content: Content) -> some View {
        // Values rather than branches, so toggling keeps the window's view identity (and its state)
        let classic = interfaceStyle == .classic
        content
            // Classic keeps the opaque toolbar under the macOS 26+ design; glass uses the system default
            .toolbarBackground(classic ? .visible : .automatic, for: .windowToolbar)
            .toolbarBackgroundVisibility(classic ? .visible : .automatic, for: .windowToolbar)
    }
}

// Scroll-edge effect: hidden in classic, the system default in glass
struct ScrollChrome: ViewModifier {
    @Environment(\.interfaceStyle) private var interfaceStyle

    func body(content: Content) -> some View {
        // A value rather than a branch, so toggling keeps the scroll view's identity
        content.scrollEdgeEffectHidden(interfaceStyle == .classic, for: .top)
    }
}

extension View {
    // Bordered rounded panel
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }

    // Tile behind the icon thumbnail
    func tileSurface() -> some View {
        modifier(TileSurface())
    }

    // Toolbar background for the current interface style
    func toolbarChrome() -> some View {
        modifier(ToolbarChrome())
    }

    // Scroll-edge effect for the current interface style
    func scrollChrome() -> some View {
        modifier(ScrollChrome())
    }
}

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

        @Environment(\.interfaceStyle) private var interfaceStyle

        // Button style
        @ViewBuilder
        var body: some View {
            switch interfaceStyle {
            case .classic:
                configuration.label
                    .fontWeight(.medium)
                    .background(Color.tileBackground)
                    .foregroundColor(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .glass:
                configuration.label
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
            }
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

        @Environment(\.interfaceStyle) private var interfaceStyle

        // Button style
        @ViewBuilder
        var body: some View {
            switch interfaceStyle {
            case .classic:
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
            case .glass:
                // Same frame, icon and colours; the glass appears under the pointer
                configuration.label
                    .fontWeight(.bold)
                    .frame(maxWidth: 38, maxHeight: 38)
                    .background {
                        if isHovering {
                            Color.clear
                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
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
}
