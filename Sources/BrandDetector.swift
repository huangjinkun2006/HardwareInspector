//  BrandDetector.swift
//  品牌识别：SMBIOS/DMI 解析 + IOKit 制造商 + system_profiler 硬件字段
//  对 Hackintosh / 虚拟机会做「机型品牌 / 引导固件 / 物理整机疑似品牌」分层判定，不误报为原厂机。

import Foundation
import IOKit

// MARK: - 数据模型

struct BrandInfo: Codable {
    let key: String          // 对应 BrandCatalog 的样式 key
    let name: String         // 品牌显示名
    let category: String     // 整机 / 处理器 / 显卡 / ...
    let model: String        // 具体型号
    let source: String       // 采集来源字段
    let note: String?
}

struct DeviceIdentity: Codable {
    let primaryBrandKey: String
    let primaryBrandName: String
    let productName: String
    let modelIdentifier: String
    let formFactor: String
    let releaseHint: String
    let firmwareBrandKey: String
    let firmwareName: String
    let physicalBrandKey: String
    let physicalBrandName: String
    let confidence: String
    let note: String
    let isGenuineApple: Bool
    let evidence: [String]
}

// MARK: - SMBIOS / DMI 解析

struct SMBIOSInfo {
    var biosVendor = "", biosVersion = "", biosDate = ""
    var systemManufacturer = "", systemProduct = "", systemVersion = "", systemFamily = ""
    var boardManufacturer = "", boardProduct = ""
    var chassisManufacturer = ""
    var cpuManufacturer = "", cpuVersion = "", cpuSocket = ""
    var isEmpty: Bool { systemManufacturer.isEmpty && biosVendor.isEmpty }
}

enum SMBIOSReader {
    static func read() -> SMBIOSInfo? {
        let s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMBIOS"))
        guard s != 0 else { return nil }
        defer { IOObjectRelease(s) }
        var p: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(s, &p, kCFAllocatorDefault, 0) == 0,
              let d = p?.takeRetainedValue() as? [String: Any],
              let data = d["SMBIOS"] as? Data else { return nil }

        let b = [UInt8](data)
        var info = SMBIOSInfo()
        var off = 0, records = 0
        while off + 4 <= b.count, records < 256 {
            records += 1
            let type = b[off]
            let len = Int(b[off + 1])
            if len < 4 || off + len > b.count { break }

            // 每条记录的字符串表：从 off+len 开始，以连续两个 0x00 结束
            var strings = [""]
            var q = off + len
            var current = [UInt8]()
            var terminated = false
            while q < b.count {
                if b[q] == 0 {
                    strings.append(String(bytes: current, encoding: .utf8) ?? "")
                    current = []
                    if q + 1 < b.count && b[q + 1] == 0 { q += 2; terminated = true; break }
                    q += 1
                } else {
                    current.append(b[q])
                    q += 1
                }
            }
            func str(_ index: Int) -> String {
                guard index < len else { return "" }
                let i = Int(b[off + index])
                return i > 0 && i < strings.count ? strings[i] : ""
            }
            switch type {
            case 0:
                info.biosVendor = str(4); info.biosVersion = str(5); info.biosDate = str(8)
            case 1:
                info.systemManufacturer = str(4); info.systemProduct = str(5)
                info.systemVersion = str(6); info.systemFamily = str(0x1A)
            case 2:
                info.boardManufacturer = str(4); info.boardProduct = str(5)
            case 3:
                info.chassisManufacturer = str(4)
            case 4:
                info.cpuSocket = str(4); info.cpuManufacturer = str(7); info.cpuVersion = str(0x10)
            default: break
            }
            if !terminated { break }
            off = q
        }
        return info.isEmpty ? nil : info
    }
}

// MARK: - 品牌识别器

enum BrandDetector {

    /// 常见 Mac 机型标识 → 产品名 / 年份
    static let macModels: [String: String] = [
        "MacBookPro16,1": "MacBook Pro 16 英寸（2019，Intel）",
        "MacBookPro16,2": "MacBook Pro 16 英寸（2019，Intel）",
        "MacBookPro16,3": "MacBook Pro 13 英寸（2020，Intel）",
        "MacBookPro17,1": "MacBook Pro 13 英寸（M1，2020）",
        "MacBookPro18,1": "MacBook Pro 16 英寸（M1 Pro / Max，2021）",
        "MacBookPro18,2": "MacBook Pro 16 英寸（M1 Max，2021）",
        "MacBookPro18,3": "MacBook Pro 14 英寸（M1 Pro，2021）",
        "MacBookPro18,4": "MacBook Pro 14 英寸（M1 Max，2021）",
        "Mac14,5": "MacBook Pro 14 英寸（M2 Pro，2023）",
        "Mac14,7": "MacBook Air 13 英寸（M2，2022）",
        "Mac14,9": "MacBook Pro 16 英寸（M2 Pro / Max，2023）",
        "Mac15,3": "MacBook Air 13 英寸（M3，2024）",
        "Mac15,6": "MacBook Pro 14 英寸（M3 Pro，2023）",
        "Mac15,12": "MacBook Air 15 英寸（M3，2024）",
        "MacBookAir10,1": "MacBook Air（M1，2020）",
        "MacBookAir9,1": "MacBook Air 13 英寸（2020，Intel）",
        "Macmini8,1": "Mac mini（2018，Intel）",
        "Macmini9,1": "Mac mini（M1，2020）",
        "Mac14,3": "Mac Studio（M1 Max / Ultra，2022）",
        "Mac14,12": "Mac mini（M2，2023）",
        "iMac20,1": "iMac 27 英寸（2020，Intel）",
        "iMac21,1": "iMac 24 英寸（M1，2021）",
        "iMac24,1": "iMac 24 英寸（M3，2023）",
        "MacPro7,1": "Mac Pro（2019，Intel Xeon）",
        "Mac13,1": "MacBook Pro 13 英寸（M1，2020）",
    ]

    /// 文本 → 硬件品牌 key（用于 CPU / GPU / 内存 / 磁盘 / 电池等）
    static func key(for text: String) -> String? {
        let t = text.lowercased()
        guard !t.isEmpty else { return nil }
        // 图形 / 处理器优先，避免 "AMD Radeon" 被当成整机品牌
        if ["nvidia", "geforce", "quadro", "gtx", "rtx", "tesla"].contains(where: t.contains) { return "nvidia" }
        if ["radeon", "ryzen", "athlon", "advanced micro", "amd "].contains(where: t.contains) || t.hasPrefix("amd") { return "amd" }
        if ["apple m1", "apple m2", "apple m3", "apple m4", "apple gpu"].contains(where: t.contains) { return "apple" }
        if ["intel", "xeon", "iris", "core i", "arc a", "celeron", "pentium"].contains(where: t.contains) { return "intel" }
        if t.contains("micron") { return "micron" }
        if t.contains("hynix") { return "skhynix" }
        if t.contains("samsung") { return "samsung" }
        if t.contains("kingston") { return "kingston" }
        if t.contains("corsair") { return "corsair" }
        if t.contains("crucial") { return "crucial" }
        if t.contains("western digital") || t.contains("wdc") || t.hasPrefix("wd ") || t.contains("wd blue") || t.contains("wd black") { return "wd" }
        if t.contains("seagate") { return "seagate" }
        if t.contains("sandisk") { return "sandisk" }
        if t.contains("toshiba") { return "toshiba" }
        if t.contains("qualcomm") || t.contains("atheros") { return "qualcomm" }
        if t.contains("broadcom") { return "broadcom" }
        if t.contains("realtek") { return "realtek" }
        if t.contains("boe") { return "boe" }
        if t.contains("philips") { return "philips" }
        if let k = oemKey(for: text) { return k }
        return nil
    }

    /// 文本 → 整机（OEM）品牌 key，白名单更严格，避免把内存/显示器厂商当整机品牌
    static func oemKey(for text: String) -> String? {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let rules: [(String, String)] = [
            ("apple inc", "apple"), ("apple", "apple"),
            ("asustek", "asus"), ("asus", "asus"), ("华硕", "asus"),
            ("lenovo", "lenovo"), ("联想", "lenovo"),
            ("dell", "dell"), ("戴尔", "dell"),
            ("hewlett", "hp"), ("HP ", "hp"), ("惠普", "hp"),
            ("acer", "acer"), ("宏碁", "acer"),
            ("micro-star", "msi"), ("msi", "msi"), ("微星", "msi"),
            ("gigabyte", "gigabyte"), ("技嘉", "gigabyte"),
            ("asrock", "asrock"), ("华擎", "asrock"),
            ("razer", "razer"), ("雷蛇", "razer"),
            ("huawei", "huawei"), ("华为", "huawei"),
            ("xiaomi", "xiaomi"), ("小米", "xiaomi"),
            ("microsoft", "microsoft"), ("微软", "microsoft"),
            ("samsung", "samsung"), ("三星", "samsung"),
            ("lg electronics", "lg"),
            ("sony", "sony"), ("索尼", "sony"),
            ("toshiba", "toshiba"), ("dynabook", "toshiba"),
            ("framework", "framework"),
            ("vmware", "vmware"), ("virtualbox", "vmware"), ("qemu", "vmware"), ("parallels", "vmware"),
        ]
        for (needle, key) in rules where t.contains(needle.lowercased()) { return key }
        return nil
    }

    // MARK: 主判定

    static func detect(
        hw: JSONDict, prof: JSONDict, platform: [String: Any],
        batteryIOK: [String: Any]?, cpuName: String,
        modelID: String, machineName: String,
        smbios: SMBIOSInfo?
    ) -> (DeviceIdentity, [BrandInfo]) {

        let maker = firstNonEmpty(smbios?.systemManufacturer, IO.dataAsString(platform["manufacturer"])) ?? "未知"
        let firmwareVendor = firstNonEmpty(smbios?.biosVendor, "") ?? ""
        let lower = maker.lowercased()
        let isOpenCore = ["acidanthera", "opencore", "clover", "hackintosh"].contains(where: lower.contains)
        let isVM = ["vmware", "virtualbox", "qemu", "parallels"].contains(where: lower.contains)
        let genuineApple = lower.contains("apple") && !isOpenCore && !isVM
        let oem = oemKey(for: maker)

        // ---- 物理整机线索（Hackintosh / 未知 OEM 时） ----
        var physicalKey = "generic"
        var physicalEvidence: [String] = []
        let powerItems = jsonArray(prof["SPPowerDataType"])
        let batMaker = firstNonEmpty(powerItems.compactMap {
            jsonString(jsonDict($0["sppower_battery_model_info"]), ["sppower_battery_manufacturer"])
        }.first, "") ?? ""
        let batModel = firstNonEmpty(powerItems.compactMap {
            jsonString(jsonDict($0["sppower_battery_model_info"]), ["sppower_battery_device_name"])
        }.first, "") ?? ""
        if let k = oemKey(for: batMaker), k != "apple" {
            physicalKey = k
            physicalEvidence.append("电池制造商 \(batMaker.trimmingCharacters(in: .whitespaces))（型号 \(batModel)）")
        }
        if physicalKey == "generic" {
            for g in jsonArray(prof["SPDisplaysDataType"]) {
                for d in jsonArray(g["spdisplays_ndrvs"]) {
                    let n = jsonString(d, ["_name"]) ?? ""
                    if let k = oemKey(for: n) { physicalKey = k; physicalEvidence.append("显示器 \(n)") ; break }
                }
                if physicalKey != "generic" { break }
            }
        }
        if genuineApple { physicalKey = "apple"; physicalEvidence = ["IOKit 与 SMBIOS 制造商均为 Apple"] }
        if !isOpenCore && !isVM, let k = oem, k != "generic" {
            physicalKey = k
            physicalEvidence = ["SMBIOS Type 1 系统制造商 \(maker)"]
        }

        // ---- 主展示品牌 ----
        let primaryKey: String
        if isVM { primaryKey = "vmware" }
        else if genuineApple { primaryKey = "apple" }
        else if isOpenCore { primaryKey = modelID.hasPrefix("Mac") ? "apple" : (physicalKey == "generic" ? "opencore" : physicalKey) }
        else if let k = oem { primaryKey = k }
        else { primaryKey = modelID.hasPrefix("Mac") ? "apple" : "generic" }

        let firmwareKey = isOpenCore ? "opencore" : (isVM ? "vmware" : primaryKey)
        let firmwareName = isOpenCore
            ? "OpenCore / Acidanthera"
            : (isVM ? "虚拟机固件" : "原厂固件")

        let releaseHint = macModels[modelID] ?? (modelID.hasPrefix("Mac") ? "机型标识 \(modelID)" : modelID)
        let productName: String
        if isVM { productName = "虚拟机 · \(smbios?.systemProduct ?? modelID)" }
        else if isOpenCore { productName = "\(machineName)（\(modelID)，模拟机型）" }
        else if genuineApple { productName = "\(machineName) · \(releaseHint)" }
        else { productName = smbios?.systemProduct ?? machineName }

        let formFactor = isVM ? "虚拟机"
            : (batteryIOK != nil || modelID.hasPrefix("MacBook")) ? "笔记本电脑" : "台式机 / 一体机"

        // ---- 证据链 ----
        var evidence: [String] = []
        evidence.append("SMBIOS Type 1 系统制造商：\(maker)")
        evidence.append("SMBIOS Type 0 BIOS 厂商：\(firmwareVendor.isEmpty ? "未读取" : firmwareVendor)")
        evidence.append("SMBIOS 产品名：\(smbios?.systemProduct ?? modelID)（\(smbios?.systemFamily ?? machineName)）")
        evidence.append("机型标识：\(modelID)  \(releaseHint)")
        evidence.append("处理器：\(cpuName)")
        if !physicalEvidence.isEmpty { evidence.append("物理整机线索：" + physicalEvidence.joined(separator: "、")) }
        let displayNames = jsonArray(prof["SPDisplaysDataType"]).flatMap { jsonArray($0["spdisplays_ndrvs"]).compactMap { jsonString($0, ["_name"]) } }
        if !displayNames.isEmpty { evidence.append("显示器件：" + displayNames.joined(separator: " / ")) }

        let note: String
        let confidence: String
        if isVM {
            note = "SMBIOS 制造商为虚拟机平台，按虚拟机识别。"
            confidence = "高"
        } else if isOpenCore {
            note = "系统 SMBIOS 由 Acidanthera / OpenCore 注入，模拟为 \(machineName)（\(modelID)）；"
                + "处理器为 \(cpuName)，并非 Apple 原厂硬件。物理整机品牌仅由器件线索推断，"
                + "指向 \(BrandCatalog.name(for: physicalKey))，置信度低。"
            confidence = "机型品牌高 / 物理品牌低"
        } else if genuineApple {
            note = "IOKit 与 SMBIOS 制造商均为 Apple，判定为 Apple 原厂机型。"
            confidence = "高"
        } else {
            note = "依据 SMBIOS Type 1 系统制造商判定整机品牌。"
            confidence = oem == nil ? "低" : "中"
        }

        let identity = DeviceIdentity(
            primaryBrandKey: primaryKey,
            primaryBrandName: BrandCatalog.name(for: primaryKey),
            productName: productName,
            modelIdentifier: modelID,
            formFactor: formFactor,
            releaseHint: releaseHint,
            firmwareBrandKey: firmwareKey,
            firmwareName: firmwareName,
            physicalBrandKey: physicalKey,
            physicalBrandName: BrandCatalog.name(for: physicalKey),
            confidence: confidence,
            note: note,
            isGenuineApple: genuineApple,
            evidence: evidence)

        // ---- 硬件品牌清单 ----
        var brands: [BrandInfo] = []
        func add(_ key: String?, _ category: String, _ model: String, _ source: String, _ note: String? = nil) {
            guard let key = key, !key.isEmpty, !model.isEmpty else { return }
            if let i = brands.firstIndex(where: { $0.key == key && $0.category == category }) {
                let old = brands[i]
                let merged = old.model.contains(model) ? old.model : old.model + "、" + model
                brands[i] = BrandInfo(key: old.key, name: old.name, category: old.category,
                                      model: merged, source: old.source, note: old.note)
            } else {
                brands.append(BrandInfo(key: key, name: BrandCatalog.name(for: key),
                                        category: category, model: model, source: source, note: note))
            }
        }

        add(primaryKey, "整机 / 机型", productName, "SMBIOS Type 1 · hw.model",
            isOpenCore ? "OpenCore 模拟机型，非原厂硬件" : nil)
        if isOpenCore {
            add("opencore", "引导固件", "Acidanthera OpenCore \(smbios?.biosVersion ?? "")", "SMBIOS Type 0")
        }
        if physicalKey != "generic" && physicalKey != primaryKey {
            add(physicalKey, "物理整机（疑似）", batModel.isEmpty ? "器件线索" : batModel,
                "IOKit 电池 · SPPowerDataType", "置信度低，仅供参考")
        }
        add(key(for: cpuName), "处理器", cpuName, "machdep.cpu.brand_string · SMBIOS Type 4")

        for g in jsonArray(prof["SPDisplaysDataType"]) {
            let name = jsonString(g, ["sppci_model", "_name"]) ?? ""
            let vendor = jsonString(g, ["spdisplays_vendor"]) ?? ""
            add(key(for: name + " " + vendor), "显卡", name, "SPDisplaysDataType")
        }
        let memRoot = jsonArray(prof["SPMemoryDataType"]).first.map(jsonDict) ?? [:]
        for d in jsonArray(memRoot["_items"]) {
            let maker = jsonString(d, ["dimm_manufacturer"]) ?? ""
            let model = [jsonString(d, ["dimm_size"]), jsonString(d, ["dimm_type"]), jsonString(d, ["dimm_speed"])]
                .compactMap { $0 }.joined(separator: " ")
            add(key(for: maker), "内存", model.isEmpty ? maker : model, "SPMemoryDataType")
        }
        for v in jsonArray(prof["SPStorageDataType"]) {
            let pd = jsonDict(v["physical_drive"])
            let name = jsonString(pd, ["device_name"]) ?? ""
            add(key(for: name), "存储", name, "SPStorageDataType")
        }
        if !batMaker.isEmpty {
            add(key(for: batMaker), "电池", [batMaker.trimmingCharacters(in: .whitespaces), batModel]
                .filter { !$0.isEmpty }.joined(separator: " "), "SPPowerDataType")
        }
        for g in jsonArray(prof["SPDisplaysDataType"]) {
            for d in jsonArray(g["spdisplays_ndrvs"]) {
                let n = jsonString(d, ["_name"]) ?? ""
                add(displayBrandKey(n), "显示器件", n, "SPDisplaysDataType · EDID")
            }
        }

        return (identity, brands)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for v in values {
            if let v = v, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return v }
        }
        return nil
    }
}
