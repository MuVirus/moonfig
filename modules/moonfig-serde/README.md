# moonfig-serde

serde backend for [moonfig](https://github.com/MuVirus/moonfig). It implements
serde's `Deserializer` over moonfig's `Value`, so any type that already carries a
serde description can be extracted straight from configuration.

This lives in its own module because `moonbit-community/serde.mbt` pulls in a
macro pipeline (`moonbitlang/parser`, `moonbitlang/async`). `moon add
MuVirus/moonfig` stays free of it; hand-written `FromConfig` needs nothing extra.

[中文](README.zh.md)

## Install

```sh
moon add MuVirus/moonfig-serde
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig-serde/serde_bridge" @serde_bridge,
}

let cfg = @config.Config::new().add(...).build()
let app : AppConfig = @serde_bridge.extract_serde_from(cfg, "app")
```

## Links

- [Choosing an extraction path](https://github.com/MuVirus/moonfig/blob/main/docs/guides/choose-extraction.md)
- [Issues](https://github.com/MuVirus/moonfig/issues)
