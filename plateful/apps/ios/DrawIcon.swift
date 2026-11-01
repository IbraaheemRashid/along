import AppKit

let output = CommandLine.arguments[1]
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: CGColor) { ctx.setFillColor(fill); ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h)) }
ctx.setFillColor(color(0.30, 0.23, 0.40)); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
ellipse(150, 570, 210, 210, color(0.91, 0.68, 0.53)); ellipse(664, 570, 210, 210, color(0.91, 0.68, 0.53))
ellipse(189, 607, 130, 130, color(0.85, 0.58, 0.50)); ellipse(704, 607, 130, 130, color(0.85, 0.58, 0.50))
ellipse(150, 170, 724, 594, color(0.94, 0.73, 0.58))
ellipse(365, 468, 29, 45, color(0.23, 0.20, 0.28)); ellipse(630, 468, 29, 45, color(0.23, 0.20, 0.28))
ellipse(258, 365, 95, 52, color(0.85, 0.58, 0.50)); ellipse(674, 365, 95, 52, color(0.85, 0.58, 0.50))
ellipse(487, 399, 50, 36, color(0.23, 0.20, 0.28))
ctx.setStrokeColor(color(0.23, 0.20, 0.28)); ctx.setLineWidth(12); ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 466, y: 370)); ctx.addQuadCurve(to: CGPoint(x: 558, y: 370), control: CGPoint(x: 512, y: 313)); ctx.strokePath()
ctx.saveGState(); ctx.translateBy(x: 520, y: 760); ctx.rotate(by: -.pi/5); ellipse(-70, -50, 220, 105, color(0.64, 0.73, 0.51)); ctx.restoreGState()
let bitmap = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Generated original Along icon")
