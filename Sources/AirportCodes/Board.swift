#if os(macOS)
import SwiftUI

enum Board {
    static let background = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let tile = Color(red: 0.13, green: 0.15, blue: 0.21)
    static let amber = Color(red: 1.0, green: 0.82, blue: 0.30)
    static let green = Color(red: 0.36, green: 0.86, blue: 0.48)
    static let red = Color(red: 1.0, green: 0.45, blue: 0.40)
}

/// One split-flap tile.
struct FlapTile: View {
    var character: Character
    var size: CGFloat
    var color: Color = Board.amber

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous).fill(Board.tile)
            Text(String(character))
                .font(.system(size: size * 0.72, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Rectangle().fill(Color.black.opacity(0.55)).frame(height: max(1, size * 0.03))
        }
        .frame(width: size * 0.74, height: size)
    }
}

/// Text on a departure board. When the text changes, the letters flip
/// through a few random letters before landing, like a real board.
struct FlapText: View {
    var text: String
    var size: CGFloat = 40
    var color: Color = Board.amber
    var animate: Bool = true

    @State private var shown: [Character] = []
    @State private var generation = 0

    private static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        HStack(spacing: size * 0.08) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, ch in
                FlapTile(character: ch, size: size, color: color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onAppear { flip(to: text) }
        .onChange(of: text) { _, newValue in flip(to: newValue) }
    }

    private func flip(to target: String) {
        let goal = Array(target.uppercased())
        guard animate else { shown = goal; return }
        generation += 1
        let mine = generation
        shown = goal.map { $0 == " " ? " " : Self.letters.randomElement()! }
        Task { @MainActor in
            for step in 0..<(goal.count + 4) {
                try? await Task.sleep(nanoseconds: 45_000_000)
                guard mine == generation else { return }
                shown = goal.enumerated().map { i, ch in
                    if ch == " " || i < step - 3 { return ch }
                    return Self.letters.randomElement()!
                }
            }
            if mine == generation { shown = goal }
        }
    }
}

/// A labeled line on the board, like "TO  SEATTLE".
struct BoardRow: View {
    var label: String
    var value: String
    var size: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 90, alignment: .leading)
            Text(value.uppercased())
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundStyle(Board.amber)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
        }
    }
}
#endif
