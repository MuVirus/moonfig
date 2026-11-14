# Extraction with `FromConfig`

> **Conclusion**: `FromConfig` is the default way to read a configuration subtree into a struct: one line per field, reading `Value` directly with no JSON round trip.
> **Authority**: Normative — the `Getter` semantics and the error rules of this path follow this document; signatures follow `.mbti`.
> **Out of scope**: Choosing between the paths is in [choose-extraction.md](../guides/choose-extraction.md); the `derive(FromJson)` and serde adapters are in [extract.md](extract.md); error text is in [errors.md](../reference/errors.md).

## 1. Shape

Each field's **label is written at the call site**:

```moonbit nocheck
impl @config.FromConfig for Server with fn from_config(get : @config.Getter) -> Server raise @config.ConfigError {
  {
    host: get.string("db-host"),          // label renamed: config key decoupled from field name
    port: get.int("port"),                // native Int64, no Int64Text
    retry: get.int32_or("retry", 3),      // default value
    comment: get.opt_string("comment"),   // optional: missing or null both give None
    tags: get.strings("tags"),            // array
    db: @jsonfmt.json_field(get, "db"),   // nested struct via derive(FromJson), one-line delegation
  }
}
let srv : Server = config.get_struct("server")
```

There are three entry points: `Config::get_struct` (take the subtree by key), `Config::get_struct_validated`
(run `Validate` after extraction) and `Value::to_struct` (the primitive; labels resolve relative to that value).

## 2. Getter semantics

| Method family | Behaviour |
|---|---|
| `string` / `bool` / `int` / `int32` / `uint64` / `float` / `float_strict` / `bytes` | Required: missing raises `MissingKey`, wrong type raises `TypeMismatch`, same rules as `get_*` |
| `*_or` | Missing uses the default; **the key exists but has the wrong type (or is out of range) still errors**, never silently falling back to the default |
| `opt_*` | Missing or `null` both give `None`; wrong type still errors |
| `strings` / `ints` / `floats` / `bools` / `structs` | element errors carry the indexed path (`server.tags.1`) |
| `nested` | the child Getter prefixes the label, nested structs recurse through `from_config` |
| `value` / `opt_value` | escape hatch: take the raw `Value` and match it yourself |
| `field_path` | the full path of a label, for custom rules and messages; it does not read a value |

## 3. Strictness

Strictness matches `get_*`: `int` accepts only integer origins (exact `Int64`; this path reads `Value` directly,
not through Json, so large integers such as 9007199254740993 do not lose precision); `float` widens integers,
`float_strict` does not; a string origin never becomes a number or a byte string. No Json round trip, no probes,
so it performs better than the derive path.

## 4. Why it is the default

MoonBit has no reflection, so the field-to-label mapping can only be built at the call site — **even when the
label equals the field name, it must be written once in the impl**. The default is `FromConfig`: it lives in core,
has zero dependencies, shares semantics with `get_*`, and does not go through Json. `derive(FromJson)` is an
optional experimental adapter ([extract.md](extract.md)), suited to simple structs whose field names all equal the config keys,
that need no defaults and have no 64-bit fields; it goes through `Value → Json` and the standard library's
`FromJson`, with strictness simulated by probes rather than guaranteed by construction. If nested structs keep
using the derive path, delegate one line per field with `json_field` instead of writing each field by hand. The
cost of one line per field equals that of a `Validate` impl: handwriting in exchange for control.
