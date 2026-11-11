//  Report.swift
//  报告渲染：终端纯文本 / Markdown / JSON

import Foundation

enum ReportRenderer {

    // MARK: - 终端文本

    static func text(_ r: HWReport) -> String {
        var out = ""
        out += "╔══════════════════════════════════════════════════════════════════════╗\n"
        out += "║  硬件检测报告  ·  Hardware Inspector                                ║\n"
        out += "╚══════════════════════════════════════════════════════════════════════╝\n"
        out += "  设备      \(r.deviceName) (\(r.machineModel))\n"
        out += "  品牌      \(r.identity.primaryBrandName) · \(r.identity.productName)\n"
        out += "  原厂判定  \(r.identity.isGenuineApple ? "Apple 原厂机型" : "非原厂机型（\(r.identity.firmwareName)）")\n"
        out += "  系统      \(r.osVersion)\n"
        out += "  采集时间  \(humanNow())\n"
        for v in r.vitals {
            out += "  \(pad(v.title, 12))\(v.value)   \(v.detail)\n"
        }
        for g in r.groups {
            out += "\n━━━ \(g.title) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            for s in g.sections {
                out += "\n  ▸ \(s.title)\n"
                let width = 20
                for it in s.items {
                    out += "    \(pad(it.label, width))\(it.value)\n"
                    if let h = it.hint, !h.isEmpty {
                        out += "    \(pad("", width))└ \(h)\n"
                    }
                }
            }
        }
        out += "\n  共 \(r.groups.count) 个分类 / \(r.groups.reduce(0) { $0 + $1.sections.count }) 个分组 / "
        out += "\(r.groups.reduce(0) { $0 + $1.sections.reduce(0) { $0 + $1.items.count } }) 项指标\n"
        return out
    }

    /// 按终端显示宽度补空格（中文/全角按 2 列宽计算）
    private static func pad(_ s: String, _ width: Int) -> String {
        let cols = s.unicodeScalars.reduce(0) { sum, scalar in
            let v = scalar.value
            let wide = (v >= 0x1100 && v <= 0x115F) || (v >= 0x2E80 && v <= 0xA4CF)
                || (v >= 0xAC00 && v <= 0xD7A3) || (v >= 0xF900 && v <= 0xFAFF)
                || (v >= 0xFE10 && v <= 0xFE19) || (v >= 0xFE30 && v <= 0xFE6F)
                || (v >= 0xFF00 && v <= 0xFF60) || (v >= 0xFFE0 && v <= 0xFFE6)
            return sum + (wide ? 2 : 1)
        }
        return s + String(repeating: " ", count: max(1, width - cols))
    }

    // MARK: - Markdown

    static func markdown(_ r: HWReport) -> String {
        var out = "# 硬件检测报告\n\n"
        out += "| 项目 | 内容 |\n| --- | --- |\n"
        out += "| 设备 | \(r.deviceName)（`\(r.machineModel)`） |\n"
        out += "| 品牌 / 型号 | \(r.identity.primaryBrandName) · \(r.identity.productName) |\n"
        out += "| 原厂判定 | \(r.identity.isGenuineApple ? "Apple 原厂机型" : "非原厂机型（\(r.identity.firmwareName)）") |\n"
        out += "| 物理整机线索 | \(r.identity.physicalBrandName)（置信度：\(r.identity.confidence)） |\n"
        out += "| 操作系统 | \(r.osVersion) |\n"
        out += "| 配置摘要 | \(r.subtitle) |\n"
        out += "| 采集时间 | \(humanNow()) |\n"
        out += "| 生成工具 | Hardware Inspector（macOS 原生 · IOKit / sysctl / Mach） |\n\n"

        out += "## 实时指标\n\n| 指标 | 数值 | 说明 |\n| --- | --- | --- |\n"
        for v in r.vitals {
            out += "| \(md(v.title)) | \(md(v.value)) | \(md(v.detail)) |\n"
        }
        out += "\n"
        for g in r.groups {
            out += "## \(g.title)\n\n"
            for s in g.sections {
                out += "### \(s.title)\n\n| 项目 | 值 | 备注 |\n| --- | --- | --- |\n"
                for it in s.items {
                    out += "| \(md(it.label)) | \(md(it.value)) | \(md(it.hint ?? "")) |\n"
                }
                out += "\n"
            }
        }
        out += "---\n\n> 本报告由本机离线采集生成，不包含任何联网上传行为。\n"
        return out
    }

    private static func md(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "`", with: "\\`")
    }

    // MARK: - JSON

    static func jsonData(_ r: HWReport) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try e.encode(r)
    }

    // MARK: - 写文件

    @discardableResult
    static func write(_ content: String, to path: String) throws -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }
}
