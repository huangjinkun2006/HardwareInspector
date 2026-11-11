#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一次性抓取「真实品牌 Logo」素材（构建时不联网，只有本脚本联网）。

来源（全部为各项目官方仓库中的品牌图形，非 AI 生成、非手绘仿制）：
  SI   simple-icons/simple-icons  (CC0)         https://github.com/simple-icons/simple-icons
  SI9  simple-icons 9.21.0 历史版 (CC0)          早期版本保留了后来因商标政策下架的品牌
  GB   gilbarbara/logos            (CC0/CDDL)    https://github.com/gilbarbara/logos
  STI  edent/SuperTinyIcons        (CC0)        https://github.com/edent/SuperTinyIcons
  OC   acidanthera/OpenCorePkg 官方 Logo          https://github.com/acidanthera/OpenCorePkg

输出到 Assets/BrandSVG/<key>.svg（原始素材）与 Assets/BrandLogos/SOURCES.json（溯源清单）。
渲染由 SVGRenderer.swift 完成，最终产物 Assets/BrandLogos/<key>.png 随 App 打包。
"""

import concurrent.futures
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(ROOT, "Assets", "BrandSVG")
OUT_DIR = os.path.join(ROOT, "Assets", "BrandLogos")
os.makedirs(SVG_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

SI = "https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/{}.svg"
SI9 = "https://raw.githubusercontent.com/simple-icons/simple-icons/9.21.0/icons/{}.svg"
GB = "https://raw.githubusercontent.com/gilbarbara/logos/main/logos/{}.svg"
STI = "https://raw.githubusercontent.com/edent/SuperTinyIcons/master/images/svg/{}.svg"
OC = "https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Docs/Logos/LogoApprox.svg"

# key -> (品牌主色, 候选来源列表)。color="original" 表示保留素材原始配色（官方渐变）
BRANDS = {
    "apple":      ("#1D1D1F", [(SI, "apple")]),
    "amd":        ("#ED1C24", [(SI, "amd")]),
    "intel":      ("#0068B5", [(SI, "intel")]),
    "nvidia":     ("#76B900", [(SI, "nvidia")]),
    "asus":       ("#00539B", [(SI, "asus")]),
    "lenovo":     ("#E2231A", [(SI, "lenovo")]),
    "dell":       ("#007DB8", [(SI, "dell")]),
    "hp":         ("#0096D6", [(SI, "hp")]),
    "acer":       ("#83B81A", [(SI, "acer")]),
    "msi":        ("#D71920", [(SI, "msi")]),
    "gigabyte":   ("#1A5FB4", [(SI9, "gigabyte"), (GB, "gigabyte")]),
    "asrock":     ("#168C9B", [(SI9, "asrock"), (GB, "asrock")]),
    "razer":      ("#2FB62C", [(SI, "razer")]),
    "huawei":     ("#CF0A2C", [(SI, "huawei")]),
    "xiaomi":     ("#FF6900", [(SI, "xiaomi")]),
    "microsoft":  ("original", [(GB, "microsoft"), (STI, "microsoft")]),
    "samsung":    ("#1428A0", [(SI, "samsung")]),
    "lg":         ("#C6002F", [(SI9, "lg"), (SI, "lg"), (GB, "lg")]),
    "sony":       ("#1D1D1F", [(SI, "sony")]),
    "toshiba":    ("#E60012", [(SI, "toshiba")]),
    "micron":     ("#0B2E73", [(GB, "micron"), (GB, "micron-icon"), (SI9, "micron")]),
    "skhynix":    ("#E3001B", [(GB, "sk-hynix")]),
    "kingston":   ("#C8102E", [(SI, "kingstontechnology"), (SI, "kingston")]),
    "corsair":    ("#B98A0B", [(SI, "corsair")]),
    "wd":         ("#0071C5", [(SI9, "westerndigital"), (SI, "westerndigital")]),
    "seagate":    ("#4E9B26", [(SI, "seagate")]),
    "crucial":    ("#E06C00", [(SI9, "crucial"), (GB, "crucial")]),
    "sandisk":    ("#E31837", [(SI9, "sandisk"), (GB, "sandisk")]),
    "qualcomm":   ("#3253DC", [(SI, "qualcomm")]),
    "broadcom":   ("#E31837", [(SI, "broadcom")]),
    "realtek":    ("#0071B9", [(SI9, "realtek"), (GB, "realtek")]),
    "boe":        ("#005CB9", [(GB, "boe"), (SI9, "boe")]),
    "philips":    ("#0B5ED7", [(GB, "philips"), (SI9, "philips")]),
    "opencore":   ("original", [("OC", OC)]),
    "vmware":     ("#607078", [(SI, "vmware")]),
    "framework":  ("#1D1D1F", [(SI, "framework")]),
}

SOURCE_NAMES = {
    SI: "Simple Icons (CC0)",
    SI9: "Simple Icons 9.21.0 (CC0)",
    GB: "gilbarbara/logos (官方品牌矢量)",
    STI: "Super Tiny Icons (CC0)",
    "OC": "Acidanthera OpenCorePkg 官方 Logo",
}


def fetch(url):
    try:
        r = subprocess.run(
            ["curl", "-sS", "-L", "--max-time", "15", "-w", "\n__CODE__%{http_code}", url],
            capture_output=True, timeout=25,
        )
        raw = r.stdout
        marker = b"\n__CODE__"
        if marker not in raw:
            return None
        body, code = raw.rsplit(marker, 1)
        if code.strip() != b"200" or b"<svg" not in body[:2000]:
            return None
        return body
    except Exception:
        return None


def resolve(item):
    key, (color, candidates) = item
    for template, slug in candidates:
        url = OC if template == "OC" else template.format(slug)
        body = fetch(url)
        if not body:
            continue
        path = os.path.join(SVG_DIR, key + ".svg")
        with open(path, "wb") as f:
            f.write(body)
        return key, {
            "key": key,
            "color": color,
            "source": SOURCE_NAMES[template],
            "url": url,
            "svg": path,
            "bytes": len(body),
        }
    return key, None


def main():
    print("抓取真实品牌 Logo 素材 ...")
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for key, info in pool.map(resolve, BRANDS.items()):
            results[key] = info
    ok = {k: v for k, v in results.items() if v}
    missing = [k for k, v in results.items() if not v]
    for k in sorted(ok):
        print("  OK    %-12s %-38s %6d B" % (k, ok[k]["source"], ok[k]["bytes"]))
    for k in sorted(missing):
        print("  --    %-12s 无可用官方素材 → 纯文字降级" % k)

    sources_path = os.path.join(OUT_DIR, "SOURCES.json")
    with open(sources_path, "w", encoding="utf-8") as f:
        json.dump({
            "note": "品牌图形均取自各项目官方仓库的真实 Logo，非生成式绘制；商标归各自权利人所有。",
            "fetched": ok,
            "missing": sorted(missing),
            "license": {
                "Simple Icons": "CC0-1.0",
                "gilbarbara/logos": "CC0 / 各商标归权利人",
                "Super Tiny Icons": "CC0",
                "OpenCorePkg": "BSD-3-Clause，Logo 归 Acidanthera",
            },
        }, f, ensure_ascii=False, indent=2)

    manifest = [{"key": k, "svg": v["svg"], "color": v["color"],
                 "out": os.path.join(OUT_DIR, k + ".png")} for k, v in sorted(ok.items())]
    manifest_path = os.path.join(OUT_DIR, "render-manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print("\n成功 %d / 共 %d；缺失 %d 个走纯文字。清单: %s" %
          (len(ok), len(BRANDS), len(missing), sources_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
