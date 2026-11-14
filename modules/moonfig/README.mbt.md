# moonfig

A native configuration library for MoonBit: declare once, gather from many
sources.

This is the core module. It contains the sources, merging, the JSON / INI /
`.env` formats, format detection, hot reload, validation and the extraction
paths that need no third-party parser. TOML, YAML, XML, CBOR and serde ship as
separate modules, so adding moonfig does not pull in a parser you do not use.

[中文](README_ZH.md)

## Install

```sh
moon add MuVirus/moonfig
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig/core/format/json_format" @jsonfmt,
}
```

## Packages

| Package | Contents |
| --- | --- |
| `core` | `Value`, `Config`, merge rules, extraction, validation |
| `core/format/json_format` | JSON text → `Value` |
| `core/format/ini_format` | INI text → `Value` |
| `core/format/dotenv_format` | `.env` text → `Value` |
| `file_source` | read a file through a `Format` |
| `env_source` | process environment variables |
| `cli_source` | command-line arguments |
| `format_detect` | suffix first, content sniffing second |
| `hot_reload` | poll files and replace the snapshot |

## Optional adapters

| You read | Add |
| --- | --- |
| TOML | `moon add MuVirus/moonfig-toml` |
| YAML | `moon add MuVirus/moonfig-yaml` |
| XML | `moon add MuVirus/moonfig-xml` |
| CBOR | `moon add MuVirus/moonfig-cbor` |
| serde-based extraction | `moon add MuVirus/moonfig-serde` |

## Links

- [Documentation](https://github.com/MuVirus/moonfig/tree/main/docs)
- [Runnable examples](https://github.com/MuVirus/moonfig/tree/main/examples)
- [Issues](https://github.com/MuVirus/moonfig/issues)
