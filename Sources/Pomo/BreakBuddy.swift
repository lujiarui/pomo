import SwiftUI

enum BreakBuddy: String, Codable, CaseIterable, Identifiable {
    case mochi, bun, sprout, byte, pip
    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return "Mochi"
        case .bun: return "Bun"
        case .sprout: return "Sprout"
        case .byte: return "Byte"
        case .pip: return "Pip"
        }
    }

    var description: String {
        switch self {
        case .mochi: return "A sleepy little cat"
        case .bun: return "A soft, bouncy bunny"
        case .sprout: return "A cheerful little seedling"
        case .byte: return "A friendly pocket robot"
        case .pip: return "A tiny mouse with rosy ears"
        }
    }

    var tint: Color {
        switch self {
        case .mochi: return Color(red: 0.88, green: 0.60, blue: 0.32)
        case .bun: return Color(red: 0.84, green: 0.49, blue: 0.65)
        case .sprout: return Color(red: 0.30, green: 0.66, blue: 0.45)
        case .byte: return Color(red: 0.39, green: 0.57, blue: 0.84)
        case .pip: return Color(red: 0.62, green: 0.54, blue: 0.77)
        }
    }

    fileprivate var bodyColor: Color {
        switch self {
        case .mochi: return Color(red: 1, green: 0.82, blue: 0.56)
        case .bun: return Color(red: 1, green: 0.91, blue: 0.93)
        case .sprout: return Color(red: 0.52, green: 0.82, blue: 0.48)
        case .byte: return Color(red: 0.63, green: 0.79, blue: 0.97)
        case .pip: return Color(red: 0.78, green: 0.77, blue: 0.87)
        }
    }

    fileprivate var accentColor: Color {
        self == .sprout ? Color(red: 0.88, green: 0.57, blue: 0.36) : tint
    }

    /// Hand-drawn pixel sprites. Dots are transparent; e marks the animated eyes.
    fileprivate var sprite: [String] {
        switch self {
        case .mochi: return [
            "....................",
            "....##......##......",
            "...#bb#....#bb#.....",
            "...#bpb####bpb#.....",
            "...#bbblbbblbb#.....",
            "..#bbblbbbbblbb#....",
            "..#bblbbbbbbblb#....",
            "..#bbbbbbbbbbbb#....",
            "..#bbebbbbebbbb#....",
            "..#bbebbbbebbbb#....",
            "..#ppbbabbabbpp#....",
            "...#bbbbabbbbb#.....",
            "....###bbb####......",
            ".....#bbbbb#....##..",
            "....#bblwlbb#..#bb#.",
            "....#bblwlbb#..#bb#.",
            "...#bbblwblbb###bb#.",
            "...#bbblwblbbbbbb#..",
            "....#bbbbbbb#####...",
            "....##bb##bb#.......",
            "....#bbb##bbb#......",
            ".....###..###.......",
            "....................",
            "...................."
        ]
        case .bun: return [
            "....##.....##.......",
            "...#ll#...#ll#......",
            "...#lp#...#pl#......",
            "...#lp#...#pl#......",
            "...#lp#...#pl#......",
            "...#ll#...#ll#......",
            "...#ll#####ll#......",
            "..#lllllllllll#.....",
            "..#lllllllllll#.....",
            ".#llllelllellll#....",
            ".#llllelllellll#....",
            ".#lpplllalllppl#....",
            "..#lllllllllll#.....",
            "...###lllll###......",
            "....#lllllll#.......",
            "...#lllbwblll#......",
            "...#lllbwblll#.##...",
            "..#llllbwbllll#ll#..",
            "...#llllllllll###...",
            "....#lllllll##......",
            "...#llll#llll#......",
            "....####.####.......",
            "....................",
            "...................."
        ]
        case .sprout: return [
            "....................",
            "...####....####.....",
            "..#bbbb#..#bbbb#....",
            "..#bblbb##bblbb#....",
            "...#bbblbblbbb#.....",
            "....###bbbl###......",
            ".......#bb#.........",
            ".......#bb#.........",
            "....##########......",
            "...#aaaaaaaaaa#.....",
            "...#alllllllla#.....",
            "....#aaaaaaaa#......",
            "....#aaeaaeaa#......",
            "....#aaeaaeaa#......",
            "....#appappaa#......",
            "....#aaaawaaa#......",
            ".....#aaaaaa#.......",
            ".....#aaaaaa#.......",
            "......######........",
            "......#a##a#........",
            ".....#aa##aa#.......",
            "......##..##........",
            "....................",
            "...................."
        ]
        case .byte: return [
            ".........aa.........",
            ".........aa.........",
            ".........##.........",
            "....############....",
            "...#bbbbbbbbbbbb#...",
            "...#bllllllllllb#...",
            "..##bl#######llb##..",
            "..abbl#e##e##llbba..",
            "..abbl#e##e##llbba..",
            "..##bl#######llb##..",
            "...#blllwwlllllb#...",
            "...#bbbbbbbbbbbb#...",
            "....############....",
            ".......#bb#.........",
            ".....########.......",
            "....#bbllllbb#......",
            "..###blabbalb###....",
            "..#bbblallalbbb#....",
            "..####bbbbbb####....",
            ".....########.......",
            "......#b##b#........",
            ".....#bb##bb#.......",
            "......##..##........",
            "...................."
        ]
        case .pip: return [
            "....................",
            "..####......####....",
            ".#bbbb#....#bbbb#...",
            ".#bppb#....#bppb#...",
            ".#bppbb####bbppb#...",
            "..#bbbbbbbbbbbb#....",
            "..#bblbbbbblbbb#....",
            ".#bblbbbbbbblbbb#...",
            ".#bbbebbbbebbbbb#...",
            ".#bbbebbbbebbbbb#...",
            ".#ppbllllplllbpp#...",
            "..#blllppplllbb#....",
            "...##lllllll###.....",
            ".....#bbbbb#........",
            "....#bblwlbb#....pp..",
            "....#bblwlbb#...p..p.",
            "....#bblwlbb#...p..p.",
            "...#bbblwblbb#.p..p.",
            "....#bbbbbbbb#pp.p..",
            "....##bb##bb#..pp...",
            "....#ppp##ppp#......",
            ".....###..###.......",
            "....................",
            "...................."
        ]
        }
    }
}

/// A quiet, flat portrait for focus mode, using the same character colors as the break sprite.
struct BuddyAvatarView: View {
    let buddy: BreakBuddy

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            context.scaleBy(x: scale, y: scale)
            let ink = Color(red: 0.27, green: 0.25, blue: 0.33)
            let pink = Color(red: 1, green: 0.66, blue: 0.73)
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
            }
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
            }
            func paint(_ path: Path, _ color: Color) {
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(ink.opacity(0.75)), lineWidth: 1.3)
            }
            func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
                Path { path in
                    path.move(to: a)
                    path.addLine(to: b)
                    path.addLine(to: c)
                    path.closeSubpath()
                }
            }
            context.fill(oval(1, 1, 46, 46), with: .color(buddy.tint.opacity(0.12)))
            switch buddy {
            case .mochi:
                paint(triangle(CGPoint(x: 11, y: 24), CGPoint(x: 10, y: 7), CGPoint(x: 25, y: 17)), buddy.bodyColor)
                paint(triangle(CGPoint(x: 23, y: 17), CGPoint(x: 38, y: 7), CGPoint(x: 37, y: 24)), buddy.bodyColor)
                context.fill(triangle(CGPoint(x: 13, y: 19), CGPoint(x: 12, y: 11), CGPoint(x: 21, y: 17)), with: .color(pink))
                context.fill(triangle(CGPoint(x: 27, y: 17), CGPoint(x: 36, y: 11), CGPoint(x: 35, y: 19)), with: .color(pink))
                paint(oval(10, 15, 28, 27), buddy.bodyColor)
            case .bun:
                paint(box(13, 3, 8, 24, 4), buddy.bodyColor)
                paint(box(27, 3, 8, 24, 4), buddy.bodyColor)
                context.fill(box(15, 6, 4, 15, 2), with: .color(pink))
                context.fill(box(29, 6, 4, 15, 2), with: .color(pink))
                paint(oval(9, 18, 30, 25), buddy.bodyColor)
            case .pip:
                paint(oval(7, 8, 15, 16), buddy.bodyColor)
                paint(oval(26, 8, 15, 16), buddy.bodyColor)
                context.fill(oval(10, 11, 9, 10), with: .color(pink))
                context.fill(oval(29, 11, 9, 10), with: .color(pink))
                paint(oval(10, 17, 28, 26), buddy.bodyColor)
            case .sprout:
                let leaves = Path { path in
                    path.move(to: CGPoint(x: 24, y: 22))
                    path.addCurve(to: CGPoint(x: 8, y: 9), control1: CGPoint(x: 9, y: 24), control2: CGPoint(x: 6, y: 15))
                    path.addCurve(to: CGPoint(x: 24, y: 19), control1: CGPoint(x: 21, y: 6), control2: CGPoint(x: 26, y: 13))
                    path.addCurve(to: CGPoint(x: 40, y: 9), control1: CGPoint(x: 23, y: 7), control2: CGPoint(x: 34, y: 5))
                    path.addCurve(to: CGPoint(x: 24, y: 22), control1: CGPoint(x: 43, y: 21), control2: CGPoint(x: 29, y: 24))
                    path.closeSubpath()
                }
                paint(leaves, buddy.bodyColor)
                context.fill(box(23, 18, 2, 9, 1), with: .color(buddy.tint))
                paint(box(12, 24, 24, 19, 6), buddy.accentColor)
                paint(box(10, 22, 28, 5, 2), Color(red: 1, green: 0.78, blue: 0.58))
            case .byte:
                context.fill(box(23, 7, 2, 8, 1), with: .color(ink))
                paint(oval(21, 3, 6, 6), buddy.tint)
                paint(box(6, 23, 5, 9, 2), buddy.tint)
                paint(box(37, 23, 5, 9, 2), buddy.tint)
                paint(box(10, 13, 28, 28, 7), buddy.bodyColor)
                context.fill(box(14, 19, 20, 16, 4), with: .color(ink))
            }
            let eyeY: CGFloat = buddy == .mochi ? 27 : (buddy == .byte ? 24 : (buddy == .sprout ? 31 : 29))
            let faceInk = buddy == .byte ? Color(red: 0.65, green: 1, blue: 0.88) : ink
            context.fill(oval(18, eyeY, 3, 4), with: .color(faceInk))
            context.fill(oval(27, eyeY, 3, 4), with: .color(faceInk))
            if buddy != .byte {
                context.fill(oval(12, eyeY + 5, 5, 3), with: .color(pink.opacity(0.8)))
                context.fill(oval(31, eyeY + 5, 5, 3), with: .color(pink.opacity(0.8)))
                context.fill(oval(22.5, eyeY + 4, 3, 2), with: .color(pink))
            }
            let smile = Path { path in
                path.move(to: CGPoint(x: 21, y: eyeY + 8))
                path.addQuadCurve(to: CGPoint(x: 27, y: eyeY + 8), control: CGPoint(x: 24, y: eyeY + 11))
            }
            context.stroke(smile, with: .color(faceInk), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(buddy.name) avatar")
        .help(buddy.name)
        .allowsHitTesting(false)
    }
}

enum BreakTips {
    static let interval = 12
    static let presets = [
        "起来走两步吧，\n我替你守着番茄钟。",
        "喝口水，\n慢慢来就好。",
        "看一眼远处，\n让眼睛歇一歇。",
        "伸个懒腰，\n松松肩膀。",
        "把鼠标放下，\n深呼吸一下。",
        "休息也算\n认真生活。",
        "离开屏幕\n一小会儿吧。",
        "你已经很专注了，\n现在轮到休息啦。"
    ]

    static func message(elapsedSeconds: Int) -> String {
        presets[(max(0, elapsedSeconds) / interval) % presets.count]
    }
}

struct PixelBuddyView: View {
    let buddy: BreakBuddy
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.3, paused: !animated || reduceMotion)) { timeline in
            let frame = animated && !reduceMotion ? Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 24 : 0
            Canvas { context, size in
                draw(in: &context, size: size, frame: frame)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(buddy.name), \(buddy.description)")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, frame: Int) {
        let unit = min(size.width, size.height) / 32
        let bounce = [0, 0, -1, -1, 0, 0, 1, 0][frame % 8]
        let blink = frame == 18 || frame == 19
        let outline = Color(red: 0.24, green: 0.23, blue: 0.30)
        let light: Color
        switch buddy {
        case .bun: light = buddy.bodyColor
        case .pip: light = Color(red: 0.95, green: 0.94, blue: 0.99)
        default: light = Color(red: 1, green: 0.96, blue: 0.85)
        }
        let palette: [Character: Color] = [
            "#": outline, "b": buddy.bodyColor, "l": light, "a": buddy.accentColor,
            "p": Color(red: 1, green: 0.63, blue: 0.68), "w": .white,
            "e": buddy == .byte ? Color(red: 0.62, green: 1, blue: 0.89) : outline
        ]
        func rect(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> Path {
            Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: CGFloat(width) * unit, height: CGFloat(height) * unit))
        }
        context.fill(rect(9, 29, 13, 1), with: .color(buddy.tint.opacity(0.16)), style: FillStyle(antialiased: false))
        for (row, line) in buddy.sprite.enumerated() {
            for (column, pixel) in line.enumerated() {
                guard let color = palette[pixel] else { continue }
                let tailWiggle = buddy == .pip && row >= 14 && column >= 15 && frame % 8 >= 4 ? -1 : 0
                if pixel == "e", blink {
                    // Keep one row for a closed-eye smile; the other blends into the face.
                    let previousIsEye = row > 0 && Array(buddy.sprite[row - 1])[column] == "e"
                    let background: Color
                    switch buddy {
                    case .byte: background = outline
                    case .mochi, .pip: background = buddy.bodyColor
                    case .bun: background = light
                    case .sprout: background = buddy.accentColor
                    }
                    context.fill(rect(column + 6, row + 3 + bounce, 1, 1), with: .color(previousIsEye ? color : background), style: FillStyle(antialiased: false))
                } else {
                    context.fill(rect(column + 6, row + 3 + bounce + tailWiggle, 1, 1), with: .color(color), style: FillStyle(antialiased: false))
                }
            }
        }
        if frame % 12 >= 6 {
            // A tiny waving paw, leaf, or robot hand.
            let hand = buddy == .sprout ? buddy.bodyColor : (buddy == .bun ? light : buddy.bodyColor)
            context.fill(rect(4, 16 + bounce, 3, 1), with: .color(outline), style: FillStyle(antialiased: false))
            context.fill(rect(3, 17 + bounce, 1, 3), with: .color(outline), style: FillStyle(antialiased: false))
            context.fill(rect(4, 17 + bounce, 2, 2), with: .color(hand), style: FillStyle(antialiased: false))
            context.fill(rect(4, 19 + bounce, 3, 1), with: .color(outline), style: FillStyle(antialiased: false))
        }
        if frame % 12 < 4 {
            context.fill(rect(27, 5, 1, 3), with: .color(buddy.tint.opacity(0.8)), style: FillStyle(antialiased: false))
            context.fill(rect(26, 6, 3, 1), with: .color(buddy.tint.opacity(0.8)), style: FillStyle(antialiased: false))
        }
    }
}

struct BreakBuddyPicker: View {
    @Binding var selection: BreakBuddy

    var body: some View {
        HStack(spacing: 6) {
            ForEach(BreakBuddy.allCases) { buddy in
                Button { selection = buddy } label: {
                    VStack(spacing: 0) {
                        PixelBuddyView(buddy: buddy, animated: false).frame(width: 48, height: 48)
                        Text(buddy.name).font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(selection == buddy ? buddy.tint.opacity(0.12) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).stroke(selection == buddy ? buddy.tint.opacity(0.65) : .clear, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(buddy.name), \(buddy.description)")
                .accessibilityAddTraits(selection == buddy ? .isSelected : [])
                .help(buddy.description)
            }
        }
    }
}

struct BreakBuddyCard: View {
    @ObservedObject var store: TimerStore

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    PixelBuddyView(buddy: store.settings.breakBuddy)
                        .frame(width: store.settings.breakBuddySize, height: store.settings.breakBuddySize)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(store.settings.breakBuddy.name) says…").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(BreakTips.message(elapsedSeconds: store.elapsedSeconds))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct FloatingBreakBuddyView: View {
    @ObservedObject var store: TimerStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("休息一下").font(.caption2.weight(.semibold)).foregroundStyle(store.settings.breakBuddy.tint)
                Text(BreakTips.message(elapsedSeconds: store.elapsedSeconds))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15).stroke(store.settings.breakBuddy.tint.opacity(0.25), lineWidth: 1)
            }
            SpeechBubbleTail().fill(.regularMaterial).frame(width: 16, height: 9).offset(y: -1)
            PixelBuddyView(buddy: store.settings.breakBuddy)
                .frame(width: store.settings.breakBuddySize, height: store.settings.breakBuddySize)
            Text(store.settings.breakBuddy.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
        }
        .padding(5)
        .frame(width: BreakBuddyPlacement.size(for: store.settings.breakBuddySize).width,
               height: BreakBuddyPlacement.size(for: store.settings.breakBuddySize).height, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
