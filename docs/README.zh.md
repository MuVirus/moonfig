# moonfig 文档

文档入口。项目定位和安装看 [README](../README_ZH.md)。

## 按处境读

| 你现在的处境 | 从这里开始 |
|---|---|
| 第一次用，想先跑起来 | [最小示例](../README_ZH.md#最小示例) → [叠加多来源](guides/layer-sources.zh.md) |
| 要把配置读进结构体 | [提取到结构体：三选一](guides/choose-extraction.zh.md) |
| 查某个能力的完整代码 | [示例](../examples/README.md) |
| 查一条错误消息的原文 | [错误参考](reference/errors.zh.md) |
| 改代码，先看模块边界 | [代码区域与文档](#代码区域与文档) |
| 写文档或改文档 | [文档检查](conventions/docs.zh.md)、[写作规则](AGENTS.zh.md) |

## 核心概念

配置从 **Source** 来（内存默认值、文件、环境变量、命令行），由 **Format** 解析成统一的
**Value** 树；`Config` 按 **MergeRule** 把各层叠成一份配置，再按键或结构体读取。
来源追踪记录一个值来自哪一层；热更新轮询文件，失败时保留旧配置。

展开解释和取舍在 `design/`；按代码找文档见[代码区域与文档](#代码区域与文档)。

## 代码区域与文档

| 代码 | 先读 |
|---|---|
| `core/` | [design.md](design/design.zh.md) |
| `core/format/*_format/` | [sources.md](design/sources.zh.md)、[format-detect.md](design/format-detect.zh.md) |
| `file_source/`、`env_source/`、`cli_source/` | [sources.md](design/sources.zh.md)、[cli-args.md](design/cli-args.zh.md) |
| `format_detect/` | [format-detect.md](design/format-detect.zh.md) |
| `hot_reload/` | [hot-reload.md](design/hot-reload.zh.md) |
| `FromConfig`、`core/from_config.mbt` | [from_config.md](design/from_config.zh.md) |
| `serde_bridge/`、`derive(FromJson)` | [extract.md](design/extract.zh.md) |
| 校验 | [validate.md](design/validate.zh.md) |
| `core/error.mbt`、错误消息 | [errors.md](reference/errors.zh.md) |
| `examples/` | [examples/README.md](../examples/README.md) |
| `scripts/` | [conventions/docs.zh.md](conventions/docs.zh.md) |

## 目录

- `guides/` —— 按任务的操作步骤
- `design/` —— 为什么这样定
- `decisions/` —— 当时为什么这么定
- `plan/` —— 接下来做什么
- `conventions/` —— 贡献者怎么做
- `reference/` —— 具体形状的查阅表
- 子目录索引和写作规则：[AGENTS.zh.md](AGENTS.zh.md)
