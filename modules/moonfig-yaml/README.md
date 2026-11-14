# moonfig-yaml

YAML adapter for [moonfig](https://github.com/MuVirus/moonfig). It turns a YAML
document into moonfig's `Value`, so merging, extraction and validation work
exactly like they do for every other format.

This lives in its own module so that `moon add MuVirus/moonfig` does not drag in
the YAML parser. Add it only when you actually read YAML.

[中文](README.zh.md)

## Install

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

## Links

- [Documentation](https://github.com/MuVirus/moonfig/tree/main/docs)
- [Issues](https://github.com/MuVirus/moonfig/issues)
