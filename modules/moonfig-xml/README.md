# moonfig-xml

XML adapter for [moonfig](https://github.com/MuVirus/moonfig). It turns an XML
document into moonfig's `Value`, so merging, extraction and validation work
exactly like they do for every other format.

This lives in its own module so that `moon add MuVirus/moonfig` does not drag in
the XML parser. Add it only when you actually read XML.

[中文](README.zh.md)

## Install

```sh
moon add MuVirus/moonfig-xml
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig-xml/xml_format" @xmlfmt,
}

let cfg = @config.Config::new()
  .add(@config.StringSource::new("<db><port>5432</port></db>", @xmlfmt.XmlFormat::new()))
  .build()
```

## Links

- [Documentation](https://github.com/MuVirus/moonfig/tree/main/docs)
- [Issues](https://github.com/MuVirus/moonfig/issues)
