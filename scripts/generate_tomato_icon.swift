import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 810),
    .paragraphStyle: paragraph
]
("🍅" as NSString).draw(in: NSRect(x: 0, y: 66, width: size.width, height: 900), withAttributes: attributes)
image.unlockFocus()

guard let data = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render tomato icon")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
