import SwiftUI

struct Monogram: View {
    var size: CGFloat = 26
    var ground: Color = .panel
    var metal = false

    var body: some View {
        let knockout: CGFloat = size < 40 ? 12 : 10
        Canvas { context, canvas in
            let scale = canvas.width / 240
            context.scaleBy(x: scale, y: scale)
            let fill: GraphicsContext.Shading = metal ? .linearGradient(metalGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: 220)) : .color(.text)
            context.fill(frame, with: fill, style: FillStyle(eoFill: true))
            context.stroke(letter, with: .color(ground), lineWidth: knockout)
            context.fill(letter, with: fill, style: FillStyle(eoFill: true))
            context.stroke(bar, with: .color(ground), lineWidth: knockout)
            context.fill(bar, with: .color(.accent))
        }
        .frame(width: size, height: size * 220 / 240)
        .accessibilityHidden(true)
    }

    private var frame: Path {
        var p = Path()
        p.addRect(CGRect(x: 30, y: 40, width: 170, height: 170))
        p.addRect(CGRect(x: 46, y: 56, width: 138, height: 138))
        return p
    }

    private var letter: Path {
        Path { p in
            p.addLines([CGPoint(x: 54, y: 210), CGPoint(x: 104, y: 10), CGPoint(x: 128, y: 10), CGPoint(x: 178, y: 210), CGPoint(x: 149, y: 210), CGPoint(x: 139, y: 170), CGPoint(x: 93, y: 170), CGPoint(x: 83, y: 210)])
            p.closeSubpath()
            p.addLines([CGPoint(x: 99, y: 144), CGPoint(x: 133, y: 144), CGPoint(x: 116, y: 74)])
            p.closeSubpath()
        }
    }

    private var bar: Path {
        Path { p in
            p.addLines([CGPoint(x: 84, y: 144), CGPoint(x: 236, y: 144), CGPoint(x: 221, y: 160), CGPoint(x: 236, y: 176), CGPoint(x: 84, y: 176)])
            p.closeSubpath()
        }
    }
}

private let metalGradient = Gradient(stops: [
    .init(color: .metalHi, location: 0),
    .init(color: .metalHi, location: 0.5),
    .init(color: .metalLo, location: 0.5),
    .init(color: .metalMid, location: 1),
])

struct Wordmark: View {
    var height: CGFloat = 15
    var metal = false

    private static let letters: [(CGFloat, [[CGPoint]])] = {
        let a: [[CGPoint]] = [[(0, 100), (35, 0), (55, 0), (90, 100), (68, 100), (61, 78), (29, 78), (22, 100)], [(35, 60), (55, 60), (45, 30)]].map { $0.map(CGPoint.init) }
        let r: [[CGPoint]] = [[(0, 0), (58, 0), (78, 20), (78, 40), (62, 54), (78, 100), (56, 100), (42, 60), (20, 60), (20, 100), (0, 100)], [(20, 18), (52, 18), (58, 24), (58, 36), (52, 42), (20, 42)]].map { $0.map(CGPoint.init) }
        let c: [[CGPoint]] = [[(20, 0), (76, 0), (76, 20), (26, 20), (20, 26), (20, 74), (26, 80), (76, 80), (76, 100), (20, 100), (0, 80), (0, 20)]].map { $0.map(CGPoint.init) }
        let m: [[CGPoint]] = [[(0, 100), (0, 0), (24, 0), (52, 50), (80, 0), (104, 0), (104, 100), (84, 100), (84, 36), (58, 82), (46, 82), (20, 36), (20, 100)]].map { $0.map(CGPoint.init) }
        let n: [[CGPoint]] = [[(0, 100), (0, 0), (22, 0), (64, 64), (64, 0), (84, 0), (84, 100), (62, 100), (20, 36), (20, 100)]].map { $0.map(CGPoint.init) }
        return [(0, a), (100, r), (188, c), (274, m), (388, a), (488, n)]
    }()

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.height / 100
            context.scaleBy(x: scale, y: scale)
            var path = Path()
            for (x, shapes) in Self.letters {
                for shape in shapes {
                    path.addLines(shape.map { CGPoint(x: $0.x + x, y: $0.y) })
                    path.closeSubpath()
                }
            }
            let fill: GraphicsContext.Shading = metal ? .linearGradient(metalGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: 100)) : .color(.text)
            context.fill(path, with: fill, style: FillStyle(eoFill: true))
        }
        .frame(width: height * 572 / 100, height: height)
        .accessibilityHidden(true)
    }
}

private extension CGPoint {
    init(_ xy: (CGFloat, CGFloat)) { self.init(x: xy.0, y: xy.1) }
}

struct Logo: View {
    var body: some View {
        HStack(spacing: 10) {
            Monogram()
            Wordmark()
        }
        .accessibilityElement()
        .accessibilityLabel("ARCMAN")
    }
}
