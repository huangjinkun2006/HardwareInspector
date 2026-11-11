//  IconGen.swift
//  用 Core Graphics 程序化绘制应用图标（无需图片素材，无需窗口服务器）

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                          bytesPerRow: 0, space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

// 翻转坐标系，让 y 从上往下，绘制更直观
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
           cornerWidth: r, cornerHeight: r, transform: nil)
}

// 蓝色渐变底板
let colors = [
    CGColor(red: 0.20, green: 0.60, blue: 1.00, alpha: 1),
    CGColor(red: 0.03, green: 0.24, blue: 0.72, alpha: 1),
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
    ctx.saveGState()
    ctx.addPath(roundRect(0, 0, S, S, 224))
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: 0, y: S), options: [])
    ctx.restoreGState()
}

// 四周引脚（白色）
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
for i in 0..<4 {
    let p: CGFloat = 352 + CGFloat(i) * 84
    for path in [
        roundRect(232, p, 96, 26, 13),
        roundRect(696, p, 96, 26, 13),
        roundRect(p, 232, 26, 96, 13),
        roundRect(p, 696, 26, 96, 13),
    ] {
        ctx.addPath(path)
        ctx.fillPath()
    }
}

// 芯片主体
ctx.addPath(roundRect(312, 312, 400, 400, 58))
ctx.fillPath()

// 内芯
ctx.setFillColor(CGColor(red: 0.07, green: 0.40, blue: 0.94, alpha: 1))
ctx.addPath(roundRect(392, 392, 240, 240, 46))
ctx.fillPath()

// 检测波形
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(20)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
let wave = CGMutablePath()
wave.move(to: CGPoint(x: 420, y: 512))
wave.addLine(to: CGPoint(x: 462, y: 512))
wave.addLine(to: CGPoint(x: 494, y: 452))
wave.addLine(to: CGPoint(x: 532, y: 574))
wave.addLine(to: CGPoint(x: 562, y: 512))
wave.addLine(to: CGPoint(x: 604, y: 512))
ctx.addPath(wave)
ctx.strokePath()

guard let image = ctx.makeImage() else { exit(1) }
let output = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
guard let dest = CGImageDestinationCreateWithURL(output, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
