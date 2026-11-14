<div align="center">

<img src="https://muvirus.github.io/%E9%A1%B9%E7%9B%AE/moonbit/moonfig/logo/moonfig.png" alt="moonbit logo" width="240">

[中文](README_ZH.md) | **English**

# moonfig

A native configuration library for MoonBit.


**Declare once, gather from many sources.**

</div>

## Contents

- [Goals](#goals)
- [Features](#features)
- [Quick start](#quick-start)
  - [Installation](#installation)
  - [Minimal example](#minimal-example)
- [Basic usage](#basic-usage)
- [Roadmap](#roadmap)
- [Documentation](#documentation)
- [License](#license)

---

## Goals

moonfig is a comprehensive configuration library built for multi-source configuration: it unifies common config files, environment variables and the command line into one model, merges them according to the configured rules, then reads by key or extracts into a struct. The core is platform-independent and works on every target.

---

## Features

- **Struct extraction**: read configuration directly into your own struct; `FromConfig`, serde and `derive(FromJson)` are supported
- **Many formats**: JSON, INI, `.env`, YAML, TOML, XML, CBOR
- **Format detection**: no need to name the format; the file suffix or content decides
- **Hot reload**: file changes apply without a restart; a bad config never takes effect
- **Layered sources**: in-memory defaults, config files, environment variables and command-line flags stack in order
- **Merge by key**: a later source overrides only the keys it shares
- **Clear errors**: messages name the key, the expected type and the actual type
- **Traceable origins**: find which file, environment variable or command-line flag a value came from
- **Validation**: required keys, ranges, custom rules and unknown-key checks

---

## Quick start

### Installation

moonfig needs the MoonBit toolchain; see the [official installation guide](https://www.moonbitlang.com/download/), and make sure `moon version` works.

Add the module to an existing MoonBit project:

```sh
moon add MuVirus/moonfig
```

Then import the packages you need in `moon.pkg`:

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig/core/format/json_format" @jsonfmt,
}
```

To run from a clone:

```sh
git clone https://github.com/MuVirus/moonfig.git
cd moonfig
moon update
moon test
moon run examples/multi_source -- --log-level=debug
```

### Minimal example

The smallest complete program is [examples/quick_start](examples/quick_start/README.md): two `StringSource`s, added in order, where the later one overrides only the keys it shares. Its `moon.pkg` has every import, so the directory runs as is.

```moonbit nocheck
// @config and @jsonfmt are the aliases from the moon.pkg import block above.
let cfg = @config.Config::new()
  .add(@config.StringSource::new("{\"db\":{\"host\":\"localhost\",\"port\":5432}}", @jsonfmt.JsonFormat::new()))
  .add(@config.StringSource::new("{\"db\":{\"port\":6543}}", @jsonfmt.JsonFormat::new()))
  .build()

cfg.get_string("db.host")   // "localhost"   ← from the first source, not overridden
cfg.get_int("db.port")      // 6543          ← overridden by the second
```

Output:

```text
db.host = localhost
db.port = 6543
```

---

## Basic usage

### Multiple sources

Configuration can come from in-memory defaults, config files, environment variables and the command line, stacked in `.add` order:

| Source | How to add |
|---|---|
| In-memory defaults | `MemorySource::new(value)` |
| Config file | `FileSource::new("config/app.json", JsonFormat::new())` |
| Environment variables | `EnvSource::new("APP_")` |
| Command line | `CliSource::new()` |

A later source overrides only the keys it shares; nested tables merge by key, arrays are replaced as a whole. The default is later-wins; you can flip to first-wins, rank by source kind, or pass a custom function.

Full example: [examples/multi_source](examples/multi_source/README.md). Layering steps and pitfalls: [guides/layer-sources.md](docs/guides/layer-sources.md).

### Read by key

Once the config is built, read values by path (for example, `db.host`) with `get_string` / `get_int` / `get_float` / `get_bool` / `get_bytes`. A missing key or a wrong type is an error.

See [examples/strict_types](examples/strict_types/README.md) for strict typing and error boundaries.

### Extract into a struct

You can also read the whole config into your own struct. Three common styles are supported: a handwritten field mapping, serde, and `derive(FromJson)`. The handwritten mapping is the default; `derive(FromJson)` is experimental and emits `alert_experimental` when used. To choose between them, see [guides/choose-extraction.md](docs/guides/choose-extraction.md). Full code:

- [examples/from_config](examples/from_config/README.md)
- [examples/serde_extract](examples/serde_extract/README.md)
- Design trade-offs: [from_config.md](docs/design/from_config.md) (default path), [extract.md](docs/design/extract.md) (all three paths)

### More examples

- Format detection: [examples/format_detect](examples/format_detect/README.md)
- Hot reload: [examples/hot_reload](examples/hot_reload/README.md)
- Source tracking: [examples/multi_source](examples/multi_source/README.md)
- Errors: [examples/multi_source](examples/multi_source/README.md#错误消息)

---

## Roadmap

| Status | Direction | Items |
|---|---|---|
| ✅ | **Core** | One value type for configuration, merge by key, read by key, read by struct, error handling... |
| ✅ | **Many formats** | Seven formats: JSON, INI, dotenv, YAML, TOML, XML and CBOR |
| ✅ | **External sources** | Configuration files, environment variables, command-line flags, any combination of sources |
| ✅ | **Source tracking** | Which layer a key finally came from |
| ✅ | **Validation** | Required keys, value ranges, custom rules |
| ✅ | **Format detection** | By suffix, by content, an error when neither decides |
| ✅ | **Hot reload** | Poll for file changes, re-read and merge, notify listeners, keep the old config when a new one is bad |
| ⬜ | **Remote configuration** | Fetch configuration files over HTTP/URL, with timeouts, retries and a local fallback. |
| ⬜ | **Encrypted storage** | Parse and securely store encrypted values for sensitive configuration fields. |
| ⬜ | **Preprocessing** | Transform existing configuration text or data without changing the source. |

✅ done (in maintenance)　🚧 in progress　⬜ not started

The full item list and the trade-offs behind them live in
[docs/plan/roadmap.md](docs/plan/roadmap.md).

---

## Documentation

| Document | Description |
|---|---|
| [Documentation](docs/README.md) | Reading paths, core concepts, and task guides |
| `moon doc` | Generate the API reference into `_build/doc/` |
| `moon doc --serve` | Start a local preview (http://127.0.0.1:3000 by default) |
| `moon coverage analyze -- -f summary` | Run the tests and print a coverage summary |
| [Examples](examples/README.md) | Runnable examples for each capability |
| [Design document](docs/design/design.md) | Core data model, plus the design and trade-offs of sources, extraction, validation and hot reload |
| [Error reference](docs/reference/errors.md) | Every `ConfigError` variant and its exact message |
| [Roadmap](docs/plan/roadmap.md) | Planned directions and progress |

> English is authoritative. Chinese copies live next to the English files: `.zh.md` under `docs/`, and `README_ZH.md` / `AGENTS_ZH.md` at the root.

---

## License

Apache-2.0

Copyright © 2026 MuVirus and PepperPocket.
