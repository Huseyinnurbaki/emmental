// Renders Resources/AppIcon.icns from the same wedge geometry as the menu bar
// icon. Run with `make icon`; the .icns is committed, so builds don't need it.
//
//   AppIcon <output.iconset>          writes every iconset size
//   AppIcon --preview <output.png>    writes one 1024px PNG
import AppKit

/// Draws the full icon at `pixels`×`pixels`, following Apple's macOS icon grid:
/// an 824px rounded square on a 1024px canvas, leaving room for the shadow.
func renderIcon(pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Work y-down in 1024-unit space, like the wedge geometry.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: size / 1024, y: -size / 1024)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Tile shadow, then a deep blue tile with a soft top-to-bottom gradient.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(0x1E2A4A))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0x34497E), rgb(0x1B2440)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: tile.minY), end: CGPoint(x: 512, y: tile.maxY), options: [])

    // The wedge, centred on the tile with a soft drop shadow. On the 64-unit
    // grid it spans x 6–58 and y 10–54, so its centre is (32, 32).
    let scale: CGFloat = 10.5
    ctx.translateBy(x: 512 - 32 * scale, y: 530 - 32 * scale)
    ctx.scaleBy(x: scale, y: scale)
    ctx.setShadow(offset: CGSize(width: 0, height: 1.2), blur: 2.5, color: CGColor(gray: 0, alpha: 0.35))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    WedgeIcon.draw(in: ctx, top: rgb(0xFFE38A), front: rgb(0xF6BF3A))
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
if args.count == 3, args[1] == "--preview" {
    writePNG(renderIcon(pixels: 1024), to: args[2])
} else if args.count == 2 {
    let iconset = args[1]
    try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
        writePNG(renderIcon(pixels: points), to: "\(iconset)/icon_\(points)x\(points).png")
        writePNG(renderIcon(pixels: points * 2), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
    }
} else {
    print("usage: AppIcon <output.iconset> | AppIcon --preview <output.png>")
    exit(1)
}
