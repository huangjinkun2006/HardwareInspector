//  SVGRenderer.swift
//  构建期工具：用 Apple WebKit 把真实品牌 SVG 渲染为透明高分辨率 PNG（512px）。
//  用法: SVGRenderer <render-manifest.json>
//  仅用于素材预处理，不随 App 分发；App 运行时完全离线、不含 WebKit 视图。

import AppKit
import WebKit
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Entry: Decodable {
    let key: String
    let svg: String
    let color: String          // "#RRGGBB" 或 "original"
    let out: String
}

let SIZE = 512

/// 把任意 viewBox 的 SVG 等比缩放并居中到 512×512 画布（留白 12%）
func normalizedSVG(_ raw: String) -> String {
    guard let tag = raw.range(of: "<svg", options: [.caseInsensitive]),
          let close = raw.range(of: ">", range: tag.upperBound..<raw.endIndex) else {
        return raw
    }
    var openTag = String(raw[tag.lowerBound..<close.lowerBound])

    var w: CGFloat = 24, h: CGFloat = 24
    let vb = "viewBox\\s*=\\s*[\"']\\s*[-+\\d.eE]+\\s*[,\\s]\\s*[-+\\d.eE]+\\s*[,\\s]\\s*([-+\\d.eE]+)\\s*[,\\s]\\s*([-+\\d.eE]+)\\s*[\"']"
    if let re = try? NSRegularExpression(pattern: vb, options: .caseInsensitive),
       let m = re.firstMatch(in: openTag, range: NSRange(location: 0, length: openTag.utf16.count)),
       m.numberOfRanges >= 3 {
        w = CGFloat(Double((openTag as NSString).substring(with: m.range(at: 1))) ?? 24)
        h = CGFloat(Double((openTag as NSString).substring(with: m.range(at: 2))) ?? 24)
    } else {
        func attr(_ name: String) -> CGFloat? {
            guard let re = try? NSRegularExpression(pattern: name + "\\s*=\\s*[\"']([\\d.]+)", options: []),
                  let m = re.firstMatch(in: openTag, range: NSRange(location: 0, length: openTag.utf16.count)) else { return nil }
            return CGFloat(Double((openTag as NSString).substring(with: m.range(at: 1))) ?? 0)
        }
        w = attr("width") ?? 24
        h = attr("height") ?? 24
    }
    guard w > 0, h > 0 else { return raw }

    let scale = min(CGFloat(SIZE) / w, CGFloat(SIZE) / h) * 0.86
    let targetW = Int((w * scale).rounded()), targetH = Int((h * scale).rounded())
    openTag = openTag.replacingOccurrences(
        of: "\\s(width|height)\\s*=\\s*[\"'][^\"']*[\"']", with: "",
        options: .regularExpression)
    openTag += " width=\"\(targetW)\" height=\"\(targetH)\""
    return openTag + String(raw[close.lowerBound...])
}

func html(for e: Entry, svg: String) -> String {
    let tint = e.color == "original" ? "" :
        "svg *{fill:\(e.color) !important;stroke:none !important;}"
    return """
    <!doctype html><html><head><meta charset="utf-8"><style>
    html,body{margin:0;padding:0;width:\(SIZE)px;height:\(SIZE)px;background:transparent;
      overflow:hidden;display:flex;align-items:center;justify-content:center}
    svg{display:block;flex:none}
    \(tint)
    </style></head><body>\(svg)</body></html>
    """
}

func writePNG(_ cg: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, cg, nil)
    return CGImageDestinationFinalize(dest)
}

func cornerAlpha(_ cg: CGImage) -> Int {
    guard let data = cg.dataProvider?.data,
          let p = CFDataGetBytePtr(data) else { return -1 }
    let off = min(3, CFDataGetLength(data) - 1)
    return Int(p[off])
}

final class Runner: NSObject, WKNavigationDelegate {
    let entries: [Entry]
    let web: WKWebView
    let hostWindow: NSWindow
    var index = 0
    var succeeded = 0

    init(_ entries: [Entry]) {
        self.entries = entries
        let cfg = WKWebViewConfiguration()
        cfg.suppressesIncrementalRendering = true
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: SIZE, height: SIZE), configuration: cfg)
        hostWindow = NSWindow(contentRect: web.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        super.init()
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        hostWindow.contentView = web
        hostWindow.isOpaque = false
        hostWindow.backgroundColor = .clear
        hostWindow.orderFrontRegardless()
    }

    func start() { load() }

    private func load() {
        guard index < entries.count else { finish(); return }
        let e = entries[index]
        guard let raw = try? String(contentsOfFile: e.svg, encoding: .utf8) else {
            print("  FAIL \(e.key): 无法读取 SVG"); index += 1; load(); return
        }
        web.loadHTMLString(html(for: e, svg: normalizedSVG(raw)), baseURL: nil)
    }

    func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) {
        let e = entries[index]
        let conf = WKSnapshotConfiguration()
        conf.rect = NSRect(x: 0, y: 0, width: SIZE, height: SIZE)
        w.takeSnapshot(with: conf) { [weak self] image, error in
            guard let self = self else { return }
            var rect = NSRect(x: 0, y: 0, width: SIZE, height: SIZE)
            if let img = image, let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil),
               writePNG(cg, to: e.out) {
                self.succeeded += 1
                print(String(format: "  OK   %-12@ %dx%d  角落alpha=%d",
                             e.key as NSString, cg.width, cg.height, cornerAlpha(cg)))
            } else {
                print("  FAIL \(e.key): \(error?.localizedDescription ?? "快照失败")")
            }
            self.index += 1
            self.load()
        }
    }

    func webView(_ w: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("  FAIL \(entries[index].key): \(error.localizedDescription)")
        index += 1
        load()
    }

    private func finish() {
        print("渲染完成: \(succeeded)/\(entries.count)")
        exit(succeeded == entries.count ? 0 : 1)
    }
}

_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.accessory)

let args = CommandLine.arguments
guard args.count >= 2,
      let data = try? Data(contentsOf: URL(fileURLWithPath: args[1])),
      let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
    print("usage: SVGRenderer <render-manifest.json>"); exit(2)
}
print("WebKit SVG 渲染: \(entries.count) 个品牌图标")
let runner = Runner(entries)
runner.start()
CFRunLoopRun()
_ = runner
