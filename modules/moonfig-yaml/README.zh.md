# moonfig-yaml

[moonfig](https://github.com/MuVirus/moonfig) 的 YAML 适配器：把 YAML 文档转成
moonfig 的 `Value`，之后的合并、提取和校验与其他格式完全一样。

单独成一个模块，是为了让 `moon add MuVirus/moonfig` 不必拉上 YAML 解析器。
只有真的要读 YAML 时才加它。

[English](README.md)

## 安装

```sh
moon add MuVirus/moonfig-yaml
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig-yaml/yaml_format" @yamlfmt,
}

let cfg = @config.Config::new()
  .add(@config.StringSource::new("port: 5432", @yamlfmt.YamlFormat::new()))
  .build()
```

## 链接

- [文档](https://github.com/MuVirus/moonfig/tree/main/docs)
- [问题反馈](https://github.com/MuVirus/moonfig/issues)
