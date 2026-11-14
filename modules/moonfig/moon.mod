// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "MuVirus/moonfig"

version = "0.2.1"

readme = "README.md"

repository = "https://github.com/MuVirus/moonfig.git"

license = "Apache-2.0"

keywords = [
  "config",
  "configuration",
  "settings",
  "merge",
  "json",
  "yaml",
  "toml",
  "xml",
  "ini",
  "env",
  "cbor",
]

preferred_target = "native"

description = "A native configuration library for MoonBit: declare once, gather from many sources."

import {
  "moonbitlang/x@0.5.5",
}
