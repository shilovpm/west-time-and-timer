import SwiftUI
import AppKit

enum AppPalette {
    static let canvas = adaptive(
        light: NSColor(srgbRed: 0.988, green: 0.984, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.090, green: 0.075, blue: 0.114, alpha: 1)
    )
    static let surface = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.129, green: 0.102, blue: 0.161, alpha: 1)
    )
    static let ink = adaptive(
        light: NSColor(srgbRed: 0.09, green: 0.075, blue: 0.12, alpha: 1),
        dark: NSColor(srgbRed: 0.973, green: 0.961, blue: 0.984, alpha: 1)
    )
    static let violet = adaptive(
        light: NSColor(srgbRed: 0.545, green: 0.173, blue: 0.961, alpha: 1),
        dark: NSColor(srgbRed: 0.761, green: 0.475, blue: 1, alpha: 1)
    )
    static let pale = adaptive(
        light: NSColor(srgbRed: 0.961, green: 0.933, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.165, green: 0.125, blue: 0.208, alpha: 1)
    )
    static let rule = adaptive(
        light: NSColor(srgbRed: 0.875, green: 0.788, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.255, green: 0.196, blue: 0.310, alpha: 1)
    )

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
