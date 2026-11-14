# moonfig-serde

[moonfig](https://github.com/MuVirus/moonfig) 的 serde 后端：在 moonfig 的
`Value` 上实现 serde 的 `Deserializer`，于是任何已经带 serde 描述的类型都能直接
从配置里提取。

单独成一个模块，是因为 `moonbit-community/serde.mbt` 会带上一整套宏管线
（`moonbitlang/parser`、`moonbitlang/async`）。`moon add MuVirus/moonfig` 不会
拉这些；手写 `FromConfig` 什么都不用加。

[English](README.md)

## 安装

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

## 链接

- [提取路径怎么选](https://github.com/MuVirus/moonfig/blob/main/docs/guides/choose-extraction.zh.md)
- [问题反馈](https://github.com/MuVirus/moonfig/issues)
