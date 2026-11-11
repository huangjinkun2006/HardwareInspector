# 硬件检测报告

| 项目 | 内容 |
| --- | --- |
| 设备 | MacBook Pro（`MacBookPro16,2`） |
| 品牌 / 型号 | Apple · MacBook Pro（MacBookPro16,2，模拟机型） |
| 原厂判定 | 非原厂机型（OpenCore / Acidanthera） |
| 物理整机线索 | 华硕 ASUS（置信度：机型品牌高 / 物理品牌低） |
| 操作系统 | macOS 26.3 (25D125) |
| 配置摘要 | AMD Ryzen™ 7 4800H  ·  17.18 GB 内存  ·  macOS 26.3 (25D125) |
| 采集时间 | 2026-11-11 12:58:43 |
| 生成工具 | Hardware Inspector（macOS 原生 · IOKit / sysctl / Mach） |

## 实时指标

| 指标 | 数值 | 说明 |
| --- | --- | --- |
| CPU 使用率 | 16.3 % | 16 逻辑核心 |
| 内存占用 | 80.3 % | 13.79 GB / 17.18 GB |
| 启动盘占用 | 65.9 % | 剩余 69.92 GB |
| 电池电量 | 100.0 % | 循环 362 次 |

## 概览

### 设备标识

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 设备名称 | MacBook Pro |  |
| 机型标识 | MacBookPro16,2 |  |
| 序列号 | C02D7CZ7ML7H |  |
| 硬件 UUID | 84581991-6000-4AD2-B8AA-BE4BA5364CA6 |  |
| 主板 ID | Mac-5F9802EFE386AA28 |  |
| 制造商 | Acidanthera |  |
| Boot ROM | 2087.0.0.0.0 |  |
| 引导器版本 | 583~4793 |  |

### 运行环境

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 操作系统 | macOS 26.3 (25D125) |  |
| 内核版本 | Darwin 25.3.0 |  |
| 编译版本 | 25D125 |  |
| 启动磁盘 | macOS Tahoe |  |
| 启动模式 | 正常模式 |  |
| 电脑名称 | 黄锦坤的MacBook Pro |  |
| 当前用户 | 黄锦坤 (huangjinkun) |  |
| 已运行 | 4 小时 8 分 |  |
| 本次开机时间 | 2026-11-11 08:49:48 |  |

### 实时状态

| 项目 | 值 | 备注 |
| --- | --- | --- |
| CPU 使用率 | 16.3 % |  |
| 内存占用 | 13.79 GB / 17.18 GB  ·  80.3 % |  |
| 启动盘占用 | 134.84 GB / 204.76 GB  ·  65.9 % |  |
| 热压力状态 | 正常 |  |
| 电池电量 | 100.0 % |  |
| 处理器温度 | — | 本版本不读取 SMC 底层传感器，避免对非标准机型造成风险 |

## 品牌识别

### 整机身份

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 机型品牌 | Apple |  |
| 产品名称 | MacBook Pro（MacBookPro16,2，模拟机型） |  |
| 机型标识 | MacBookPro16,2 |  |
| 产品定位 | MacBook Pro 16 英寸（2019，Intel） |  |
| 设备形态 | 笔记本电脑 |  |
| 原厂判定 | 非原厂机型 / 模拟机型 |  |
| 引导固件 | OpenCore / Acidanthera |  |
| 物理整机线索 | 华硕 ASUS | 由器件线索推断，置信度低 |
| 识别置信度 | 机型品牌高 / 物理品牌低 |  |
| 判定说明 | 系统 SMBIOS 由 Acidanthera / OpenCore 注入，模拟为 MacBook Pro（MacBookPro16,2）；处理器为 AMD Ryzen™ 7 4800H，并非 Apple 原厂硬件。物理整机品牌仅由器件线索推断，指向 华硕 ASUS，置信度低。 |  |

### 识别依据

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 证据 1 | SMBIOS Type 1 系统制造商：Acidanthera |  |
| 证据 2 | SMBIOS Type 0 BIOS 厂商：Acidanthera |  |
| 证据 3 | SMBIOS 产品名：MacBookPro16,2（MacBook Pro） |  |
| 证据 4 | 机型标识：MacBookPro16,2  MacBook Pro 16 英寸（2019，Intel） |  |
| 证据 5 | 处理器：AMD Ryzen™ 7 4800H |  |
| 证据 6 | 物理整机线索：电池制造商 ASUS（型号 A32-K55） |  |
| 证据 7 | 显示器件：HM7606 / VE198 |  |

### 硬件品牌清单（10 项）

| 项目 | 值 | 备注 |
| --- | --- | --- |
| Apple | MacBook Pro（MacBookPro16,2，模拟机型） | 整机 / 机型 · 来源 SMBIOS Type 1 · hw.model · OpenCore 模拟机型，非原厂硬件 |
| OpenCore / Acidanthera | Acidanthera OpenCore 2087.0.0.0.0 | 引导固件 · 来源 SMBIOS Type 0 |
| 华硕 ASUS | A32-K55 | 物理整机（疑似） · 来源 IOKit 电池 · SPPowerDataType · 置信度低，仅供参考 |
| AMD | AMD Ryzen™ 7 4800H | 处理器 · 来源 machdep.cpu.brand_string · SMBIOS Type 4 |
| NVIDIA | NVIDIA GeForce RTX 2060 | 显卡 · 来源 SPDisplaysDataType |
| AMD | AMD Radeon RX Graphics | 显卡 · 来源 SPDisplaysDataType |
| 美光 Micron | 8 GB DDR4 3200 MHz | 内存 · 来源 SPMemoryDataType |
| 西部数据 WD | WDC PC SN530 SDBPNPZ-512G-1002、WD Blue SN570 1TB SSD、WDC WD10SPCX-21KHST0 | 存储 · 来源 SPStorageDataType |
| 华硕 ASUS | ASUS A32-K55 | 电池 · 来源 SPPowerDataType |
| 华硕 ASUS | VE198 | 显示器件 · 来源 SPDisplaysDataType · EDID |

## 处理器

### 规格

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 处理器型号 | AMD Ryzen™ 7 4800H |  |
| 架构 | x86_64 |  |
| 制造商 | AuthenticAMD |  |
| 标称主频 | 2.9 GHz |  |
| 总线频率 | 2.90 GHz |  |
| 物理封装 | 1 |  |
| 物理核心 | 8 核 |  |
| 逻辑核心 | 16 线程 |  |
| 超线程 | 已启用 |  |
| 每核二级缓存 | 512 KB |  |
| 三级缓存 | 8 MB |  |
| 二级缓存总量 | 524 KB |  |
| 缓存行大小 | 64 字节 |  |

### 指令集与特性

| 项目 | 值 | 备注 |
| --- | --- | --- |
| AES 硬件加速 | 支持 |  |
| AVX | 支持 |  |
| AVX2 | 支持 |  |
| ARM64 | 不适用 |  |
| CPU 特性标志 | FPU VME DE PSE TSC MSR PAE MCE CX8 APIC SEP MTRR PGE MCA CMOV PAT PSE36 CLFSH MMX FXSR SSE SSE2 HTT SSE3 PCLMULQDQ MON SSSE3 FMA CX16 SSE4.1 SSE4.2 MOVBE POPCNT AES XSAVE OSXSAVE AVX1.0 RDRAND F16C |  |
| 扩展特性标志 | SYSCALL XD 1GBPAGE EM64T LAHF LZCNT PREFETCHW RDTSCP TSCI |  |
| Family / Model | 23 / 96 |  |

### 负载统计（自开机累计）

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 用户态 | 32.1 % |  |
| 系统态 | 9.3 % |  |
| 空闲 | 58.6 % |  |
| Nice | 0.0 % |  |
| 瞬时采样 (250 ms) | 16.3 % |  |
| 活跃处理器数 | 16 / 16 |  |

## 内存

### 内存总览

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 总容量 | 17.18 GB |  |
| 已使用 | 13.79 GB  ·  80.3 % |  |
| 可回收缓存 | 3.33 GB |  |
| 可用 | 3.39 GB |  |
| 页面大小 | 4 KB |  |
| 内存是否可升级 | 否 |  |
| ECC | 未启用 |  |
| 交换分区总量 | 7.52 GB |  |
| 交换分区已用 | 5.9 GB  ·  已加密 |  |

### 内存条 1  ·  P0 CHANNEL A/DIMM 0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 容量 | 8 GB |  |
| 类型 | DDR4 |  |
| 频率 | 3200 MHz |  |
| 厂商 | Micron Technology |  |
| 部件号 | 4ATF1G64HZ-3G2E1 |  |
| 序列号 | 27996E03 |  |
| 状态 | 正常 |  |

### 内存条 2  ·  P0 CHANNEL B/DIMM 0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 容量 | 8 GB |  |
| 类型 | DDR4 |  |
| 频率 | 3200 MHz |  |
| 厂商 | Micron Technology |  |
| 部件号 | 4ATF1G64HZ-3G2E1 |  |
| 序列号 | 27996E72 |  |
| 状态 | 正常 |  |

### 虚拟内存明细（页计数换算）

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 联动内存 (Wired) | 8.58 GB |  |
| 活跃 (Active) | 3.31 GB |  |
| 非活跃 (Inactive) | 3.32 GB |  |
| 压缩内存 | 1.89 GB |  |
| 空闲 (Free) | 69.9 MB |  |
| 推测页 (Speculative) | 15.7 MB |  |
| 可清除 (Purgeable) | 12.9 MB |  |
| 内部页 / 外部页 | 1107928 / 514736 页 |  |
| 换入 / 换出 | 12683561 / 197148 页 |  |
| Swap 换入 / 换出 | 18120546 / 19766707 页 |  |
| 缺页异常 | 1147280009 次 |  |

## 显卡与显示

### 显卡 1  ·  NVIDIA GeForce RTX 2060

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 名称 | NVIDIA GeForce RTX 2060 |  |
| 厂商 | NVIDIA |  |
| 显存 | 6 GB |  |
| 设备 ID | 0x1f15 |  |
| 修订 ID | 0x00a1 |  |
| 总线 | PCI Express |  |
| 链路宽度 | x8 |  |
| Metal 支持 | Metal 4 |  |

### 显卡 2  ·  AMD Radeon RX Graphics

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 名称 | AMD Radeon RX Graphics |  |
| 厂商 | AMD |  |
| 显存 | 4 GB |  |
| 设备 ID | 0x1636 |  |
| 修订 ID | 0x00c6 |  |
| 总线 | PCI Express |  |
| 链路宽度 | x16 |  |
| Metal 支持 | Metal 3 |  |

### 显示器  ·  HM7606

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 名称 | HM7606 |  |
| 分辨率 | 1920 x 1080 @ 144.00Hz |  |
| 像素密度 | 1080p |  |
| 连接类型 | 内置显示器 |  |
| 产品 ID | 6060 |  |
| 显示器序列号 | 46821920 |  |
| 生产年 / 周 | 2023 / 1 |  |

### 显示器  ·  VE198

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 名称 | VE198 |  |
| 分辨率 | 1920 x 1080 @ 60.00Hz |  |
| 像素密度 | 1080p |  |
| 主显示器 | 是 |  |
| 产品 ID | 19ea |  |
| 生产年 / 周 | 2014 / 39 |  |

## 存储

### 物理磁盘  ·  WDC PC SN530 SDBPNPZ-512G-1002

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 型号 | WDC PC SN530 SDBPNPZ-512G-1002 |  |
| 介质名称 | WDC PC SN530 SDBPNPZ-512G-1002 Media |  |
| 介质类型 | 固态硬盘 (SSD) |  |
| 接口协议 | PCI-Express |  |
| 内置磁盘 | 是 |  |
| 分区图 | GUID 分区表 |  |
| SMART 状态 | 正常 (Verified) |  |

### 物理磁盘  ·  WD Blue SN570 1TB SSD

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 型号 | WD Blue SN570 1TB SSD |  |
| 介质名称 | WD Blue SN570 1TB SSD Media |  |
| 介质类型 | 固态硬盘 (SSD) |  |
| 接口协议 | PCI-Express |  |
| 内置磁盘 | 是 |  |
| 分区图 | GUID 分区表 |  |
| SMART 状态 | 正常 (Verified) |  |

### 物理磁盘  ·  Disk Image

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 型号 | Disk Image |  |
| 介质名称 | AppleAPFSMedia |  |
| 接口协议 | Disk Image |  |
| 内置磁盘 | 否 |  |
| 分区图 | unknown partition map type |  |

### 物理磁盘  ·  WDC WD10SPCX-21KHST0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 型号 | WDC WD10SPCX-21KHST0 |  |
| 介质名称 | WDC WD10SPCX-21KHST0 Media |  |
| 介质类型 | 机械硬盘 (HDD) |  |
| 接口协议 | PCI |  |
| 内置磁盘 | 是 |  |
| 分区图 | GUID 分区表 |  |
| SMART 状态 | 正常 (Verified) |  |

### 物理磁盘  ·  DataTraveler 3.0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 型号 | DataTraveler 3.0 |  |
| 介质名称 | Kingston DataTraveler 3.0 Media |  |
| 接口协议 | USB |  |
| 内置磁盘 | 否 |  |
| 分区图 | master boot record partition map type |  |

### 卷  ·  Win10Home X64

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | Win10Home X64 |  |
| BSD 设备 | disk0s4 |  |
| 文件系统 | NTFS |  |
| 挂载点 | /Volumes/Win10Home X64 |  |
| 总容量 | 239.01 GB |  |
| 已使用 | 212.47 GB  ·  88.9 % |  |
| 可用 | 26.54 GB |  |
| 可写 | 否 |  |
| 卷 UUID | 3B57B11C-151C-4224-9621-357459017886 |  |

### 卷  ·  软件

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | 软件 |  |
| BSD 设备 | disk0s6 |  |
| 文件系统 | NTFS |  |
| 挂载点 | /Volumes/软件 |  |
| 总容量 | 265.47 GB |  |
| 已使用 | 200.1 GB  ·  75.4 % |  |
| 可用 | 65.37 GB |  |
| 可写 | 否 |  |
| 卷 UUID | 9DF272DA-5BDE-42ED-9623-308963094CE9 |  |

### 卷  ·  娱乐

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | 娱乐 |  |
| BSD 设备 | disk1s1 |  |
| 文件系统 | NTFS |  |
| 挂载点 | /Volumes/娱乐 |  |
| 总容量 | 794.42 GB |  |
| 已使用 | 544.42 GB  ·  68.5 % |  |
| 可用 | 250 GB |  |
| 可写 | 否 |  |
| 卷 UUID | FEBC7CB4-62A4-41D7-AD9C-A5DB12721D31 |  |

### 卷  ·  macOS Tahoe - 数据

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | macOS Tahoe - 数据 |  |
| BSD 设备 | disk2s1 |  |
| 文件系统 | APFS |  |
| 挂载点 | /System/Volumes/Data |  |
| 总容量 | 204.76 GB |  |
| 已使用 | 134.84 GB  ·  65.9 % |  |
| 可用 | 69.92 GB |  |
| 可写 | 是 |  |
| 卷 UUID | DBF7D0AB-524C-428E-AC8B-BC0E5A368A6C |  |

### 卷  ·  Creedence11M6270.SECUREPKITRUSTSTOREASSETS_SECUREPKITRUSTSTORE_Cryptex

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | Creedence11M6270.SECUREPKITRUSTSTOREASSETS_SECUREPKITRUSTSTORE_Cryptex |  |
| BSD 设备 | disk8s1 |  |
| 文件系统 | Case-sensitive APFS |  |
| 挂载点 | /System/Library/AssetsV2/com_apple_MobileAsset_PKITrustStore/purpose_auto/6dd55b0d06633a00de6f57ccb910a66a5ba2409a.asset/.AssetData |  |
| 总容量 | 4.2 MB |  |
| 已使用 | 1 MB  ·  24.9 % |  |
| 可用 | 3.1 MB |  |
| 可写 | 否 |  |
| 卷 UUID | A4B97E21-47AA-4E5E-A5D5-1F7563C37536 |  |

### 卷  ·  微信 WeChat

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | 微信 WeChat |  |
| BSD 设备 | disk10s1 |  |
| 文件系统 | APFS |  |
| 挂载点 | /Volumes/微信 WeChat |  |
| 总容量 | 2.09 GB |  |
| 已使用 | 1.52 GB  ·  72.6 % |  |
| 可用 | 571.8 MB |  |
| 可写 | 否 |  |
| 卷 UUID | F94048F3-00A6-455B-A911-2DCA3069B2B1 |  |

### 卷  ·  EWEADN-E-HUB-3.3.5

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | EWEADN-E-HUB-3.3.5 |  |
| BSD 设备 | disk12s1 |  |
| 文件系统 | APFS |  |
| 挂载点 | /Volumes/EWEADN-E-HUB-3.3.5 |  |
| 总容量 | 385.3 MB |  |
| 已使用 | 296.7 MB  ·  77.0 % |  |
| 可用 | 88.5 MB |  |
| 可写 | 否 |  |
| 卷 UUID | 290AAA9E-2076-4EDA-B85E-578698FCA490 |  |

### 卷  ·  macOS Tahoe

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | macOS Tahoe |  |
| BSD 设备 | disk2s4s1 |  |
| 文件系统 | APFS |  |
| 挂载点 | / |  |
| 总容量 | 204.76 GB |  |
| 已使用 | 134.84 GB  ·  65.9 % |  |
| 可用 | 69.92 GB |  |
| 可写 | 否 |  |
| 卷 UUID | 7A490383-FF17-4B5E-9A8F-1AB4A99827C5 |  |

### 卷  ·  存储

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | 存储 |  |
| BSD 设备 | disk3s3 |  |
| 文件系统 | NTFS |  |
| 挂载点 | /Volumes/存储 |  |
| 总容量 | 999.87 GB |  |
| 已使用 | 915.5 GB  ·  91.6 % |  |
| 可用 | 84.37 GB |  |
| 可写 | 否 |  |
| 卷 UUID | 88E670E4-EA50-4016-913F-84C9883CA238 |  |

### 卷  ·  金士顿128G

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | 金士顿128G |  |
| BSD 设备 | disk4s1 |  |
| 文件系统 | ExFAT |  |
| 挂载点 | /Volumes/金士顿128G |  |
| 总容量 | 123.95 GB |  |
| 已使用 | 119.07 GB  ·  96.1 % |  |
| 可用 | 4.87 GB |  |
| 可写 | 是 |  |
| 卷 UUID | 4EE99282-3BA2-327C-9E95-720FC25D9E6C |  |

### 卷  ·  GLFriend 1.1

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 卷名称 | GLFriend 1.1 |  |
| BSD 设备 | disk13s1 |  |
| 文件系统 | HFS+ |  |
| 挂载点 | /Volumes/GLFriend 1.1 |  |
| 总容量 | 7.8 MB |  |
| 已使用 | 4.5 MB  ·  58.0 % |  |
| 可用 | 3.3 MB |  |
| 可写 | 否 |  |
| 卷 UUID | 01E18CB8-A460-35FC-AE53-CD53247B80AD |  |

## 电池与电源

### 电池状态 (IOKit · AppleSmartBattery)

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 当前电量 | 100.0 % |  |
| 充电状态 | 已接通电源 |  |
| 当前容量 | 2622 mAh |  |
| 最大容量 | 2622 mAh |  |
| 设计容量 | 4110 mAh |  |
| 健康度 | 63.8 % | 低于 80%，建议检修电池 |
| 循环次数 | 362 次 |  |
| 电池温度 | 20.0 °C |  |
| 电压 | 12139 mV |  |
| 外接电源 | 已连接 |  |

### 电池信息 (system_profiler)

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 电量百分比 | 100 % |  |
| 最大容量 | 2622 mAh |  |
| 正在充电 | 否 |  |
| 已充满 | 是 |  |
| 循环次数 | 362 次 |  |
| 健康结论 | 建议检修电池 |  |
| 电池型号 | A32-K55 |  |
| 制造商 | ASUS  |  |
| 固件版本 | 0000 |  |

## 网络

### 接口  ·  Ethernet

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 服务名称 | Ethernet |  |
| BSD 设备 | en0 |  |
| 硬件类型 | Ethernet |  |
| MAC 地址 | 3c:7c:3f:5a:d7:73 |  |
| IPv4 配置 | DHCP |  |
| IPv6 配置 | 自动 |  |
| 接口状态 | 已启用 |  |
| 介质子类型 | 自动选择 |  |

### 接口  ·  Wi-Fi

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 服务名称 | Wi-Fi |  |
| BSD 设备 | en1 |  |
| 硬件类型 | AirPort |  |
| MAC 地址 | 84:7b:57:91:6a:36 |  |
| IPv4 地址 | 192.168.1.3 |  |
| IPv6 地址 | 2409:8a34:462:1c90:1085:6ab:cdd3:4c19, 2409:8a34:462:1c90:d9ca:acf5:959f:cec9 |  |
| IPv4 配置 | DHCP |  |
| IPv6 配置 | 自动 |  |
| 路由器 | 192.168.1.1 |  |
| 子网掩码 | 255.255.255.0 |  |
| DNS | 192.168.1.1, fe80::1 |  |
| 接口状态 | 已启用 |  |
| 介质子类型 | 自动选择 |  |

### 无线局域网  ·  en1

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 当前网络 | <redacted> | 系统隐私保护隐藏了 SSID，可在「系统设置 → 隐私与安全性」中授权后重试 |
| 信道 / 频段 | 48 (5GHz, 160MHz) |  |
| PHY 模式 | 802.11ac |  |
| 信号 / 噪声 | -62 dBm / 60 dBm |  |
| 加密方式 | WPA2 个人级 |  |
| 周边网络数 | 13 |  |
| 接口 | en1 |  |

### 其他接口  ·  utun0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| BSD 设备 | utun0 |  |
| IPv6 | fe80::d36c:b7ca:41a6:2ad6 |  |
| 状态 | 已启用 |  |

### 其他接口  ·  utun1

| 项目 | 值 | 备注 |
| --- | --- | --- |
| BSD 设备 | utun1 |  |
| IPv6 | fe80::b761:aa68:c6b5:3cfa |  |
| 状态 | 已启用 |  |

### 其他接口  ·  utun2

| 项目 | 值 | 备注 |
| --- | --- | --- |
| BSD 设备 | utun2 |  |
| IPv6 | fe80::cbf7:a87d:44be:7ff0 |  |
| 状态 | 已启用 |  |

### 其他接口  ·  utun3

| 项目 | 值 | 备注 |
| --- | --- | --- |
| BSD 设备 | utun3 |  |
| IPv6 | fe80::ce81:b1c:bd2c:69e |  |
| 状态 | 已启用 |  |

### 其他接口  ·  lo0

| 项目 | 值 | 备注 |
| --- | --- | --- |
| BSD 设备 | lo0 |  |
| IPv4 | 127.0.0.1 |  |
| IPv6 | ::1, fe80::1 |  |
| 状态 | 已启用 |  |
| 回环接口 | 是 |  |

## 系统与安全

### 系统信息

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 系统版本 | macOS 26.3 (25D125) |  |
| 系统内部版本 | 25D125 |  |
| Darwin 内核 | Darwin Kernel Version 25.3.0: Wed Jan 28 20:53:14 PST 2026; root:xnu-12377.81.4~5/RELEASE_X86_64 |  |
| 内核架构 | x86_64 |  |
| 字节序 | 小端 (Little Endian) |  |
| 主机名称 | huangjinkundemacbook-pro.local |  |
| 登录用户 | huangjinkun |  |
| 时区 | 中国标准时间 |  |
| 首选语言 | zh-Hans-CN |  |
| 系统运行时间 | 4 小时 8 分 |  |
| 采集时间 | 2026-11-11 12:58:43 |  |

### 安全与启动

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 系统完整性保护 (SIP) | 已关闭 |  |
| 安全虚拟机 | 已启用 |  |
| 启动模式 | 正常模式 |  |
| 启动卷 | macOS Tahoe |  |
| 应用标识 | 独立可执行文件 |  |

### 传感器与功耗

| 项目 | 值 | 备注 |
| --- | --- | --- |
| 热压力状态 | 正常 | 由 Foundation 的 ProcessInfo.thermalState 提供 |
| 电池温度 | 20.0 °C |  |
| CPU / 风扇转速 | — | 底层 SMC 传感器需内核驱动配合，本工具不越权读取 |
| 当前供电 | 交流电源 |  |

---

> 本报告由本机离线采集生成，不包含任何联网上传行为。
