# moonfig-cbor

[moonfig](https://github.com/MuVirus/moonfig) 的 CBOR 适配器：把 CBOR 文档转成
moonfig 的 `Value`，之后的合并、提取和校验与其他格式完全一样。

单独成一个模块，是为了让 `moon add MuVirus/moonfig` 不必拉上 CBOR 解析器。
只有真的要读 CBOR 时才加它。

[English](README.md)

## 安装

```sh
moon add MuVirus/moonfig-cbor
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig-cbor/cbor_format" @cborfmt,
}
```

## 链接

- [文档](https://github.com/MuVirus/moonfig/tree/main/docs)
- [问题反馈](https://github.com/MuVirus/moonfig/issues)
