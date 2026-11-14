<div align="center">

<img src="https://muvirus.github.io/%E9%A1%B9%E7%9B%AE/moonbit/moonfig/logo/moonfig.png" alt="moonbit logo" width="240">

[English](README.mbt.md) | **中文**

# moonfig

MoonBit 原生配置库


**一处声明，多来源汇入**

</div>

## 目录

- [项目目标](#项目目标)
- [功能特性](#功能特性)
- [快速开始](#快速开始)
  - [安装](#安装)
  - [最小示例](#最小示例)
- [基本用法](#基本用法)
- [开发路线图](#开发路线图)
- [文档](#文档)
- [许可证](#许可证)

---

## 项目目标

moonfig 是一个综合性配置库，面向多来源配置：把常见配置格式文件、环境变量和命令行统一成一份配置，按合并规则叠加，再按键或结构体读取。core 部分不依赖平台，全平台可用。

---

## 功能特性

- **结构体提取**：把配置直接读进自己的结构体；支持 `FromConfig`、serde 和 `derive(FromJson)`
- **多格式支持**：JSON、INI、dotenv、YAML、TOML、XML、CBOR
- **自动发现格式**：不用指定格式，按文件后缀或内容判断
- **热更新**：文件改了不用重启，坏配置不会生效
- **多层来源**：内存默认值、配置文件、环境变量、命令行参数按顺序叠加
- **按键合并**：后加入的来源只覆盖同名键，其余键保留
- **错误信息明确**：错误消息带键名、期望类型和实际类型
- **来源可追**：能查某个值来自哪个文件、环境变量或命令行参数
- **可校验**：支持必填、范围、自定义规则和未知键检查

---

## 快速开始

### 安装

需要 MoonBit 工具链，安装方法见 [MoonBit 官方文档](https://www.moonbitlang.com/download/)；装好后 `moon version` 应该能输出版本号。

在已有 MoonBit 项目里加依赖：

```sh
moon add MuVirus/moonfig
```

TOML、YAML、XML、CBOR 和 serde 各自是独立模块，只读 JSON 的项目不会把它们的
解析器拉进来。哪种格式该加哪个模块，见
[模块 README](modules/moonfig/README.zh.md#可选适配器)。

然后在 `moon.pkg` 里按需引入包：

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig/core/format/json_format" @jsonfmt,
}
```

从源码运行（库本身在 `modules/moonfig/`）：

```sh
git clone https://github.com/MuVirus/moonfig.git
cd moonfig
moon update
moon test
moon run examples/multi_source -- --log-level=debug
```

### 最小示例

最小可运行程序是 [examples/quick_start](examples/quick_start/README.md)：两个 `StringSource` 按顺序叠加，后加入的只覆盖同名键。它的 `moon.pkg` 里导入齐全，整个目录可以直接运行。

```moonbit nocheck
// @config 和 @jsonfmt 是上面 moon.pkg 导入块里的别名。
let cfg = @config.Config::new()
  .add(@config.StringSource::new("{\"db\":{\"host\":\"localhost\",\"port\":5432}}", @jsonfmt.JsonFormat::new()))
  .add(@config.StringSource::new("{\"db\":{\"port\":6543}}", @jsonfmt.JsonFormat::new()))
  .build()

cfg.get_string("db.host")   // "localhost"   ← 第一个来源提供，未被覆盖
cfg.get_int("db.port")      // 6543          ← 第二个来源覆盖
```

输出：

```text
db.host = localhost
db.port = 6543
```

---

## 基本用法

### 多来源支持

配置可以从内存默认值、配置文件、环境变量和命令行来，按 `.add` 顺序叠加：

| 来源 | 写法 |
|---|---|
| 内存默认值 | `MemorySource::new(value)` |
| 配置文件 | `FileSource::new("config/app.json", JsonFormat::new())` |
| 环境变量 | `EnvSource::new("APP_")` |
| 命令行 | `CliSource::new()` |

后加的来源覆盖同名键；嵌套配置逐层合并，数组整体替换。默认后加者优先，也可以改成先加者优先、按来源类型排序，或传自定义函数。

完整示例：[examples/multi_source](examples/multi_source/README.md)。分层步骤和常见坑见
[guides/layer-sources.zh.md](docs/guides/layer-sources.zh.md)。

### 按键取值

配置建好后按路径（如 `db.host`）取值：`get_string` / `get_int` / `get_float` / `get_bool` / `get_bytes`。缺键或类型不符会直接报错。

完整示例：[examples/strict_types](examples/strict_types/README.md)。

### 提取到结构体

也可以把整棵配置读进自己的结构体。支持三种常见写法：手写字段映射、serde、`derive(FromJson)`。手写映射是默认路径；`derive(FromJson)` 是实验性的，使用时会有 `alert_experimental` 提示。怎么选见
[guides/choose-extraction.zh.md](docs/guides/choose-extraction.zh.md)；完整代码：

- [examples/from_config](examples/from_config/README.md)
- [examples/serde_extract](examples/serde_extract/README.md)
- 设计取舍：[from_config.zh.md](docs/design/from_config.zh.md)（默认路径）、[extract.zh.md](docs/design/extract.zh.md)（三条路径）

### 更多示例

- 自动发现格式：[examples/format_detect](examples/format_detect/README.md)
- 热更新：[examples/hot_reload](examples/hot_reload/README.md)
- 来源追踪：[examples/multi_source](examples/multi_source/README.md)
- 错误处理：[examples/multi_source](examples/multi_source/README.md#错误消息)

---

## 开发路线图

| 状态 | 方向 | 条目 |
|---|---|---|
| ✅ | **核心** | 统一的配置值类型、按键合并、按键取值、按结构体取值、错误处理... |
| ✅ | **多格式** | JSON、INI、dotenv、YAML、TOML、XML、CBOR 七种格式 |
| ✅ | **外部来源** | 配置文件、环境变量、命令行、多个来源任意组合 |
| ✅ | **来源追踪** | 某个键最终来自哪一层 |
| ✅ | **校验** | 必填项、取值范围、自定义规则 |
| ✅ | **自动发现格式** | 按后缀判断、按内容判断、无法判断时报错 |
| ✅ | **热更新** | 轮询文件变化、重新读取并合并、回调通知、失败时保留旧配置 |
| ⬜ | **远程配置支持** | 支持通过 HTTP/URL 在线拉取配置文件，支持超时重试与本地兜底。 |
| ⬜ | **加密存储** | 支持敏感配置字段的加密解析与安全存储。 |
| ⬜ | **预处理数据** | 支持对原有配置文本或者数据进行加工处理，不改变源数据 |

✅ 已完成（进入维护）　🚧 进行中　⬜ 未进行

完整的条目和取舍见 [docs/plan/roadmap.zh.md](docs/plan/roadmap.zh.md)。

---

## 文档

| 文档 | 说明 |
|---|---|
| [文档导航](docs/README.zh.md) | 阅读路径、核心概念，以及按任务的操作指南 |
| `moon doc` | 生成 API 文档到 `_build/doc/` |
| `moon doc --serve` | 启动本地预览（默认 http://127.0.0.1:3000） |
| `moon coverage analyze -- -f summary` | 跑测试并打印覆盖率摘要 |
| [示例](examples/README.md) | 每个能力的可运行示例 |
| [设计文档](docs/design/design.zh.md) | 核心数据模型，以及来源、提取、校验、热更新等模块的设计与取舍 |
| [错误参考](docs/reference/errors.zh.md) | `ConfigError` 每个变体和消息原文 |
| [路线图](docs/plan/roadmap.zh.md) | 待实现的方向与进度 |

---

## 许可证

Apache-2.0

Copyright © 2026 MuVirus and PepperPocket.
