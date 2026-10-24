import AppKit

/// The nibbled Swiss cheese wedge, drawn as a template image so macOS tints it
/// for light and dark menu bars. Geometry is authored on a 64×64 grid, y-down.
enum WedgeIcon {
    static func image(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: size / 64, y: size / 64)
            // The wedge points right; the path below is authored pointing left.
            ctx.translateBy(x: 64, y: 0)
            ctx.scaleBy(x: -1, y: 1)

            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineJoin(.round)
            for face in [topFace(), frontFace()] {
                ctx.addPath(face)
                ctx.fillPath(using: .evenOdd)
                ctx.addPath(face)
                ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func topFace() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 6, y: 28))
        p.addLine(to: CGPoint(x: 18, y: 22.32))
        p.addBite(to: CGPoint(x: 24, y: 19.47), radius: 3.4)
        p.addLine(to: CGPoint(x: 44, y: 10))
        p.addLine(to: CGPoint(x: 58, y: 20))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: 38, y: 15.7, width: 8, height: 3.6))
        return p
    }

    private static func frontFace() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 6, y: 32))
        p.addLine(to: CGPoint(x: 14, y: 30.77))
        p.addBite(to: CGPoint(x: 22, y: 29.54), radius: 4.1)
        p.addLine(to: CGPoint(x: 42, y: 26.46))
        p.addBite(to: CGPoint(x: 48, y: 25.54), radius: 3.1)
        p.addLine(to: CGPoint(x: 58, y: 24))
        p.addLine(to: CGPoint(x: 58, y: 46))
        p.addLine(to: CGPoint(x: 30, y: 50.31))
        p.addBite(to: CGPoint(x: 24, y: 51.23), radius: 3.1)
        p.addLine(to: CGPoint(x: 6, y: 54))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: 30.5, y: 32.5, width: 11, height: 11))
        p.addEllipse(in: CGRect(x: 50, y: 34, width: 4, height: 4))
        return p
    }
}

private extension CGMutablePath {
    /// A small circular arc that curves into the shape, like SVG's `A r r 0 0 0 x y`
    /// on a clockwise outline: a bite taken out of the edge.
    func addBite(to end: CGPoint, radius r: CGFloat) {
        let start = currentPoint
        let half = CGPoint(x: (start.x - end.x) / 2, y: (start.y - end.y) / 2)
        let halfSq = half.x * half.x + half.y * half.y
        let k = -sqrt(max(0, (r * r - halfSq) / halfSq))
        let center = CGPoint(x: k * half.y + (start.x + end.x) / 2,
                             y: -k * half.x + (start.y + end.y) / 2)
        addArc(center: center,
               radius: r,
               startAngle: atan2(start.y - center.y, start.x - center.x),
               endAngle: atan2(end.y - center.y, end.x - center.x),
               clockwise: true)
    }
}
