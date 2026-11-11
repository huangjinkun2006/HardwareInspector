//  BrandLogo.swift
//  真实品牌 Logo 加载器 —— 不包含任何程序化绘制 / 生成式的品牌图形。
//
//  素材来源（构建期一次性抓取，运行时完全离线）：
//    Simple Icons (CC0)、gilbarbara/logos、Acidanthera OpenCorePkg 官方 Logo
//    详见 Assets/BrandLogos/SOURCES.json；商标归各自权利人所有，仅用于设备识别展示。
//
//  加载优先级：
//    1) ~/Library/Application Support/HardwareInspector/BrandLogos/<key>.png  （用户自备官方 Logo）
//    2) App bundle 内 Resources/BrandLogos/<key>.png                        （随 App 分发的真实素材）
//    3) 无素材时：仅显示品牌文字（系统字体），不画任何仿制图形
//
//  底板只是中性容器（圆角 + 细边框），不是 Logo 本身。底板固定为浅色：
//  多数官方 Logo 为深色字标，浅底才能保证深浅色外观下都不丢失对比度。

import AppKit
import CoreGraphics
import CoreText

// MARK: - 品牌名称表（不含任何图形样式）

enum BrandCatalog {

    struct Name {
        let display: String     // 完整显示名
        let short: String       // 无素材时的纯文字降级
    }

    static let names: [String: Name] = {
        var d: [String: Name] = [:]
        func add(_ key: String, _ display: String, _ short: String) {
            d[key] = Name(display: display, short: short)
        }
        add("apple", "Apple", "Apple")
        add("amd", "AMD", "AMD")
        add("intel", "Intel", "Intel")
        add("nvidia", "NVIDIA", "NVIDIA")
        add("asus", "华硕 ASUS", "ASUS")
        add("lenovo", "联想 Lenovo", "Lenovo")
        add("dell", "戴尔 Dell", "DELL")
        add("hp", "惠普 HP", "hp")
        add("acer", "宏碁 Acer", "acer")
        add("msi", "微星 MSI", "msi")
        add("gigabyte", "技嘉 GIGABYTE", "GIGABYTE")
        add("asrock", "华擎 ASRock", "ASRock")
        add("razer", "雷蛇 Razer", "RAZER")
        add("huawei", "华为 HUAWEI", "HUAWEI")
        add("xiaomi", "小米 Xiaomi", "MI")
        add("microsoft", "微软 Microsoft", "Microsoft")
        add("samsung", "三星 SAMSUNG", "SAMSUNG")
        add("lg", "LG", "LG")
        add("sony", "索尼 Sony", "SONY")
        add("toshiba", "东芝 Toshiba", "TOSHIBA")
        add("micron", "美光 Micron", "micron")
        add("skhynix", "SK hynix", "SK hynix")
        add("kingston", "金士顿 Kingston", "Kingston")
        add("corsair", "海盗船 Corsair", "CORSAIR")
        add("wd", "西部数据 WD", "WD")
        add("seagate", "希捷 Seagate", "SEAGATE")
        add("crucial", "英睿达 Crucial", "crucial")
        add("sandisk", "闪迪 SanDisk", "SanDisk")
        add("qualcomm", "高通 Qualcomm", "Qualcomm")
        add("broadcom", "博通 Broadcom", "Broadcom")
        add("realtek", "瑞昱 Realtek", "Realtek")
        add("boe", "京东方 BOE", "BOE")
        add("philips", "飞利浦 Philips", "PHILIPS")
        add("opencore", "OpenCore / Acidanthera", "OC")
        add("vmware", "VMware 虚拟机", "VMware")
        add("framework", "Framework", "FRAMEWORK")
        add("generic", "未识别品牌", "?")
        return d
    }()

    static func name(for key: String) -> String { info(for: key).display }
    static func info(for key: String) -> Name { names[key] ?? names["generic"]! }
    static func hasStyle(_ key: String) -> Bool { names[key] != nil }   // 兼容旧调用
}

// MARK: - Logo 加载与排版

enum BrandLogo {

    private static let cache = NSCache<NSString, NSImage>()

    /// 用户自备官方 Logo 的目录（优先于随 App 分发的素材）
    static var customDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HardwareInspector/BrandLogos", isDirectory: true)
    }

    static var customDirectoryPath: String { customDirectory.path }

    /// GUI 启动时创建自定义 Logo 目录，方便用户直接放入官方 PNG
    static func prepare() {
        try? FileManager.default.createDirectory(at: customDirectory,
                                                 withIntermediateDirectories: true)
    }

    /// 该品牌是否有真实图片素材（含用户自定义）
    static func hasRealLogo(_ key: String) -> Bool { loadSource(for: key) != nil }

    static func image(for key: String, size: CGFloat = 48) -> NSImage {
        let cacheKey = "\(key)@\(Int(size * 10))@\(fileStamp(for: key))" as NSString
        if let hit = cache.object(forKey: cacheKey) { return hit }
        let img = render(key: key, size: size)
        cache.setObject(img, forKey: cacheKey)
        return img
    }

    // MARK: 资源定位

    private static func loadSource(for key: String) -> CGImage? {
        let name = key + ".png"
        let fm = FileManager.default

        // 1) 用户自定义
        let custom = customDirectory.appendingPathComponent(name)
        if let img = cgImage(at: custom) { return img }

        // 2) App bundle 内资源
        if let bundleURL = Bundle.main.resourceURL {
            let bundled = bundleURL.appendingPathComponent("BrandLogos/" + name)
            if let img = cgImage(at: bundled) { return img }
        }

        // 3) 命令行裸二进制：与可执行文件同目录（或项目 Assets 目录）
        let exec = Bundle.main.executableURL?.deletingLastPathComponent()
        if let dir = exec {
            for candidate in [dir.appendingPathComponent("BrandLogos/" + name),
                              dir.appendingPathComponent("Assets/BrandLogos/" + name)] {
                if fm.fileExists(atPath: candidate.path), let img = cgImage(at: candidate) { return img }
            }
        }
        return nil
    }

    private static func cgImage(at url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private static func fileStamp(for key: String) -> UInt64 {
        let fm = FileManager.default
        let custom = customDirectory.appendingPathComponent(key + ".png")
        if let a = try? fm.attributesOfItem(atPath: custom.path),
           let d = a[.modificationDate] as? Date { return UInt64(d.timeIntervalSince1970) }
        return 0
    }

    // MARK: 渲染（只画中性底板，Logo 本身来自真实素材）

    private static func render(key: String, size s: CGFloat) -> NSImage {
        let scale: CGFloat = 2
        let px = max(8, Int((s * scale).rounded()))
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: s, height: s))
        }
        ctx.scaleBy(x: scale, y: scale)

        let plate = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                           cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
        ctx.addPath(plate)
        ctx.setFillColor(CGColor(red: 0.965, green: 0.972, blue: 0.982, alpha: 1))
        ctx.fillPath()
        ctx.addPath(plate)
        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
        ctx.setLineWidth(max(0.5, s * 0.012))
        ctx.strokePath()

        if let logo = loadSource(for: key) {
            let box = CGRect(x: s * 0.09, y: s * 0.09, width: s * 0.82, height: s * 0.82)
            let iw = CGFloat(logo.width), ih = CGFloat(logo.height)
            let ratio = min(box.width / iw, box.height / ih)
            let w = iw * ratio, h = ih * ratio
            ctx.draw(logo, in: CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h))
        } else {
            // 无真实素材：只放品牌文字，不绘制任何仿制图形
            drawPlainText(ctx, s, BrandCatalog.info(for: key).short)
        }

        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: s, height: s)) }
        return NSImage(cgImage: cg, size: NSSize(width: s, height: s))
    }

    private static func drawPlainText(_ ctx: CGContext, _ s: CGFloat, _ text: String) {
        let count = text.count
        let r: CGFloat = count <= 2 ? 0.40 : count <= 4 ? 0.28 : count <= 6 ? 0.21 : count <= 8 ? 0.16 : 0.13
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, s * r, nil)
        let fg = CGColor(red: 0.24, green: 0.26, blue: 0.30, alpha: 1)
        let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: fg] as CFDictionary
        guard let str = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs) else { return }
        let line = CTLineCreateWithAttributedString(str)
        var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
        let maxWidth = s * 0.84
        if width > maxWidth {
            ctx.saveGState()
            ctx.translateBy(x: s / 2, y: s / 2)
            ctx.scaleBy(x: maxWidth / width, y: 1)
            ctx.textPosition = CGPoint(x: -width / 2, y: -(a + d) / 2 + d)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        } else {
            ctx.textPosition = CGPoint(x: (s - width) / 2, y: (s - (a + d)) / 2 + d)
            CTLineDraw(line, ctx)
        }
    }
}
