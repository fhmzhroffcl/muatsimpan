// Composites the provided brand logo into a native macOS rounded-square icon.
// Usage: swift make-icon.swift <source.png> <out.png>
import AppKit

let args = CommandLine.arguments
let srcPath = args.count > 2 ? args[1] : "muat simpan black.png"
let outPath = args.count > 2 ? args[2] : args[1]

let canvas: CGFloat = 1024
guard let src = NSImage(contentsOfFile: srcPath) else { fatalError("cannot load \(srcPath)") }

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: content sits in ~824/1024 with rounded-square mask.
let inset: CGFloat = canvas * 0.09
let rect = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let path = CGPath(roundedRect: rect,
                  cornerWidth: rect.width * 0.2237,
                  cornerHeight: rect.width * 0.2237,
                  transform: nil)
ctx.saveGState()
ctx.addPath(path)
ctx.clip()
// Fill black (the source already has a black background; keep it seamless).
ctx.setFillColor(NSColor.black.cgColor)
ctx.fill(rect)
// Draw the source logo to fill the rounded tile.
src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
ctx.restoreGState()

image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
