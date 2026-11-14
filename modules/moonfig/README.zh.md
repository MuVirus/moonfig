# moonfig

MoonBit 原生配置库：一处声明，多来源汇入。

这是核心模块，包含来源、合并、JSON / INI / `.env` 三种格式、格式探测、热重载、
校验，以及不需要第三方解析器的提取路径。TOML、YAML、XML、CBOR 和 serde 各自
是独立模块，加 moonfig 不会拉上用不到的解析器。

[English](README.md)

## 安装

```sh
moon add MuVirus/moonfig
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig/core/format/json_format" @jsonfmt,
}
```

## 包

| 包 | 内容 |
| --- | --- |
| `core` | `Value`、`Config`、合并规则、提取、校验 |
| `core/format/json_format` | JSON 文本 → `Value` |
| `core/format/ini_format` | INI 文本 → `Value` |
| `core/format/dotenv_format` | `.env` 文本 → `Value` |
| `file_source` | 通过 `Format` 读文件 |
| `env_source` | 进程环境变量 |
| `cli_source` | 命令行参数 |
| `format_detect` | 先后缀，后内容探测 |
| `hot_reload` | 轮询文件并替换快照 |

## 可选适配器

| 你要读 | 要加 |
| --- | --- |
| TOML | `moon add MuVirus/moonfig-toml` |
| YAML | `moon add MuVirus/moonfig-yaml` |
| XML | `moon add MuVirus/moonfig-xml` |
| CBOR | `moon add MuVirus/moonfig-cbor` |
| serde 提取 | `moon add MuVirus/moonfig-serde` |

## 链接

- [文档](https://github.com/MuVirus/moonfig/tree/main/docs)
- [可运行示例](https://github.com/MuVirus/moonfig/tree/main/examples)
- [问题反馈](https://github.com/MuVirus/moonfig/issues)
