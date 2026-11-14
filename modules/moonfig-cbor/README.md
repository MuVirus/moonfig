# moonfig-cbor

CBOR adapter for [moonfig](https://github.com/MuVirus/moonfig). It turns a CBOR
document into moonfig's `Value`, so merging, extraction and validation work
exactly like they do for every other format.

This lives in its own module so that `moon add MuVirus/moonfig` does not drag in
the CBOR parser. Add it only when you actually read CBOR.

[中文](README.zh.md)

## Install

```sh
moon add MuVirus/moonfig-cbor
```

```moonbit
import {
  "MuVirus/moonfig/core" @config,
  "MuVirus/moonfig-cbor/cbor_format" @cborfmt,
}
```

## Links

- [Documentation](https://github.com/MuVirus/moonfig/tree/main/docs)
- [Issues](https://github.com/MuVirus/moonfig/issues)
