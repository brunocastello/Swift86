//
//  PathControl.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - PathControl

// Path bar like Finder
struct PathControl: View {

    // MARK: - Properties

    // Path
    @Binding var path: String

    // One clickable component of the path
    private struct Segment: Identifiable {
        let id: Int
        let name: String
        let fullPath: String
        let icon: NSImage
    }

    // MARK: - Segments

    // Split the path into components, from the root to the item
    private var segments: [Segment] {
        // Interpret user home folder paths
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        var current = ""
        return url.pathComponents.enumerated().map { index, component in
            current = index == 0 ? component : (current as NSString).appendingPathComponent(component)
            return Segment(id: index, name: FileManager.default.displayName(atPath: current), fullPath: current, icon: NSWorkspace.shared.icon(forFile: current))
        }
    }

    // MARK: - Scene

    var body: some View {
        let all = segments
        
        // Show as many components as fit, replacing the leading ones with an ellipsis
        ViewThatFits(in: .horizontal) {
            ForEach(0..<max(all.count - 1, 1), id: \.self) { hidden in
                row(all, hidden: hidden)
                    .fixedSize()
            }
            
            // Last component only, truncating its name if it still does not fit
            row(all, hidden: max(all.count - 1, 0))
        }
        // Stable width so the window does not grow with the path length
        .frame(minWidth: 240, idealWidth: 320, maxWidth: 320, minHeight: 22, idealHeight: 22, maxHeight: 22, alignment: .leading)
        .help(path)
    }

    // MARK: - Views

    // A row of segments with the first `hidden` ones collapsed into an ellipsis
    private func row(_ all: [Segment], hidden: Int) -> some View {
        HStack(spacing: 4) {
            if hidden > 0 {
                Text("…")
                    .font(.callout)
                chevron
            }
            
            let visible = Array(all.dropFirst(hidden))
            ForEach(visible) { segment in
                // Select this folder
                Button(action: {
                    path = segment.fullPath
                }) {
                    HStack(spacing: 3) {
                        Image(nsImage: segment.icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(segment.name)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .buttonStyle(.plain)
                
                if segment.id != all.last?.id {
                    chevron
                }
            }
        }
    }

    // Separator between segments
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(.secondary)
    }
}
