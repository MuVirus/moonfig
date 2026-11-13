# Extraction into structs

> **Conclusion**: `FromConfig` is the default extraction path; `derive(FromJson)` and `serde_bridge` are optional adapters.
> **Authority**: Normative — the type mapping and error translation of the three paths follow this document; signatures follow `.mbti`.
> **Out of scope**: Choice steps are in [choose-extraction.md](../guides/choose-extraction.md); history is in [decisions.md](../decisions/decisions.md).

## 1. Interface

Default extraction goes through `FromConfig` (see section 3). Below are the entry points of the `derive(FromJson)` adapter:

```moonbit
pub fn[T : FromJson] extract(v : Value) -> T raise ConfigError
pub fn[T : FromJson] extract_from(cfg : Config, path : String) -> T raise ConfigError
pub fn[T : FromJson + Validate] extract_validated_from(cfg : Config, path : String) -> T raise ConfigError
```

`extract` extracts the whole tree, `extract_from` first takes the subtree by key and then extracts; the latter is a free function because methods cannot cross packages (see [decisions.md](../decisions/decisions.md#2-methods-cannot-cross-packages)). `extract_validated_from` calls the struct's own `Validate` after extraction, see [validate.md](validate.md).

The implementation main line is `@json.from_json(to_json(v))`, but integer mapping has one unavoidable contradiction:

| Field type | What `from_json` in the MoonBit standard library accepts |
|---|---|
| `Int` / `Int32` | `Json::Number` (range-checked to ±2^31) |
| `Int64` / `UInt64` | `Json::String` (strings only) |

`extract[T : FromJson]` only has a value-level constraint and cannot see field types, so one Json tree cannot satisfy both. The trade-off: **map everything to numbers**, and use wrapper types for 64-bit fields.

The standard library's `Int::from_json` only range-checks numbers, so `3.14` is truncated by `to_int()` to `3`. After a successful normal decode, if the original value tree contains a float, `extract` decodes once more with a probe tree that turns every float into the string `"NaN"`: `Double` / `Float` accept `"NaN"`, integer types do not, so it can locate "a float trying to enter an integer field" and raise `TypeMismatch`. Configs without floats skip this extra pass, and `Double` fields still return the original value, unaffected by the probe.

JSON decoding sets `preserve_number_repr=true`, so numbers like `1.0`, `1e2` and `-0.0` whose "value is integer but spelling is float" also stay `Float`, are caught by the probe too, and do not bypass the integer field check just because the value is integral.

The string side needs probing as well, because some standard-library `FromJson` impls treat strings as other shapes:

| Standard-library behaviour | Problem | Probe handling |
|---|---|---|
| `Double` / `Float` accept the strings `"NaN"`, `"Infinity"`, `"-Infinity"` | a string origin becomes a float | replace every `Str` with an ordinary marker and decode again; if the expected type is `Float`, translate to `TypeMismatch` |
| `Int64` / `UInt64` parse strings directly | a string origin becomes a 64-bit integer, bypassing `Int64Text` | same as above; if the expected type is `Int64` / `UInt64`, translate to `TypeMismatch` |
| `Bytes` fields accept only strings | a string origin becomes a byte string | the marker contains a newline, which `Bytes::from_json` rejects |

The reverse direction has a pitfall too: `Bytes` and `Str` both map to `Json::String`, so a normal decode cannot tell them apart. `extract` replaces each `Bytes` node with a non-string value and decodes again, one at a time: a bytes field then reports an expectation of `Bytes` (fine), while a string field reports an expectation of `String`, showing that a bytes origin was taken for a string, and that is translated to `TypeMismatch`. Replacing with a non-string value rather than `null` avoids optional types treating `null` as the default and letting it pass. These probes run only when the corresponding shape appears in the tree, so pure-string or pure-integer configs skip them.

| ValueKind | → Json |
|---|---|
| `Int` | `Json::number(i.to_double(), repr=i.to_string())` |
| `Float` | `Json::number` |
| `Bool` | `Json::bool` |
| `Str` | `Json::string` |
| `Bytes` | `Json::string(...)`, using the standard library's byte encoding |
| `Null` | `Json::null` |
| `Array` / `Table` | recursive |

`repr` is the standard library's own field: `Json::stringify` writes it first, so `to_json(Value::int(9007199254740993L)).stringify()` is still the original text `9007199254740993`, losing no precision through `Double`. `Int64Text` / `UInt64Text` read it too; declare 64-bit struct fields as `id : Int64Text` and get the original value back with `to_int64()`.

Parsing side and measured data are in [decisions.md](../decisions/decisions.md#4-boundaries-of-json-numbers).

Another cost: a `Double` field receiving an integer beyond 2^53 takes an approximation as a `Double` (`Double` cannot hold it anyway); an `Int` field beyond ±2^31 gets an overflow from the standard library, which the library translates to "out of range for Int". The key path behaves the same: `get_float` accepts integers and widens them by default, `get_float_strict` accepts only `Float`.

`Bytes` follows the same idea: the standard library's `ToJson for Bytes` prints printable ASCII as is and everything else as `\xHH`, and `FromJson for Bytes` reads exactly that format (`moonbitlang/core/json/from_json.mbt:309`). Both ends are standard-library implementations, so the library writes no encoder of its own and cannot drift from the standard library.

## 2. Error messages

`derive(FromJson)` throws `JsonDecodeError((JsonPath, String))`, where `JsonPath`'s `Show` is a JSON Pointer (`/db/port`). `extract` looks that path up in the `Value` and translates it into the same error set as `get_*`:

| Situation | Error |
|---|---|
| Missing field (`Missing field port`) | `MissingKey("db.port")` |
| Type mismatch (`Int::from_json: expected number`) | `TypeMismatch("db.port", "Int", "Str")` |
| Integer overflow (`Int::from_json: overflow`) | `ParseError("key 'db.port' is out of range for Int")` |
| Struct declares `Int64` (`expected number in string representation`) | `ParseError("key 'db.port' is a 64-bit integer: declare the struct field as Int64Text or use get_int")` |

The expected type comes from the standard library's message prefix (`String` → `Str`, `Double` → `Float`, `Map` → `Table`), and the actual type is looked up from the `Value`, so names in messages match `get_*`. Variant fields and message text are in [errors.md](../reference/errors.md).

## 3. Default extraction (`FromConfig`): field labels

`FromConfig` is the default extraction path: it reads field by field from a `Value` and does not go through Json. Each field's
**label is inlined at the call site**:

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

### Getter semantics

| Method family | Behaviour |
|---|---|
| `string` / `bool` / `int` / `int32` / `uint64` / `float` / `float_strict` / `bytes` | Required: missing raises `MissingKey`, wrong type raises `TypeMismatch`, same rules as `get_*` |
| `*_or` | Missing uses the default; **the key exists but has the wrong type (or is out of range) still errors**, never silently falling back to the default |
| `opt_*` | Missing or `null` both give `None`; wrong type still errors |
| `strings` / `ints` / `floats` / `bools` / `structs` | element errors carry the indexed path (`server.tags.1`) |
| `nested` | the child Getter prefixes the label, nested structs recurse through `from_config` |
| `value` / `opt_value` | escape hatch: take the raw `Value` and match it yourself |

Strictness matches `get_*`: `int` accepts only integer origins (exact `Int64`; this path reads `Value` directly,
not through Json, so large integers such as 9007199254740993 do not lose precision); `float` widens integers, `float_strict` does not;
a string origin never becomes a number or a byte string. No Json round trip, no probes, so it performs better than the derive path.

### Division of labour with the derive path

MoonBit has no reflection, so the field-to-label mapping can only be built at the call site — **even when the label equals the field name,
it must be written once in the impl**. The default is `FromConfig`: it lives in core, has zero dependencies, shares semantics with `get_*`,
and does not go through Json. `derive(FromJson)` is an optional adapter, suited to simple structs whose field names all equal the config keys,
that need no defaults and have no 64-bit fields; it goes through `Value → Json` and the standard library's `FromJson`,
with strictness simulated by probes rather than guaranteed by construction. If nested structs keep using the derive path, delegate one line per field with
`json_field` instead of writing each field by hand. The cost of one line per field equals that of a `Validate` impl:
handwriting in exchange for control.

## 4. Combining with serde (`serde_bridge`)

The [MoonBit community serde framework](https://github.com/moonbit-community/serde.mbt) (`moonbit-community/serde.mbt`) separates "types describing their own shape" from "formats reading and writing the data model": types implement `Deserialize` (by hand or via its derive generator), formats implement `Deserializer`. The `serde_bridge` package provides a `Deserializer` backend over moonfig's `Value`, so any serde type can be extracted straight from config:

```moonbit nocheck
// type side: existing serde user code, moonfig is unaware of it
impl @serde.Deserialize for Server with fn deserialize(d) -> Server raise @serde.DeError {
  d.deserialize_struct_begin("Server", ["db-host", "port"])
  // ... the struct protocol reads field by field, required closes it
}

// moonfig side: three entry points
let srv : Server = @serde_bridge.extract_serde(value)          // whole tree
let srv : Server = @serde_bridge.extract_serde_from(cfg, "srv") // by key
db: @serde_bridge.serde_field(get, "db"),                      // FromConfig field-level delegation
```

Semantics align with serde's own `Value` backend and with moonfig's strictness: integers accept only `Int` nodes
(range-checked, floats not truncated, strings not parsed), `deserialize_double` widens integers (like `get_float`),
and a string origin cannot become a number or a byte string. `DeError` is translated to `ConfigError` at the entry points: serde's
`MissingField`/`InvalidType`/`InvalidValue` map to `MissingKey`/`TypeMismatch`/
`InvalidValue`, and key names are prefixed with the extraction path (`$.db.port` → `key 'srv.db.port'`).

Dependency note: moon.mod therefore pulls in `moonbit-community/serde.mbt@0.3.1` (which itself depends only on
moonbitlang core, plus parser/async for its derive generator). Users who do not use serde are unaffected: neither core nor json_format depends on it, and existing APIs change in no way.

A complete runnable example (type attributes + generator output + three entry points) is in
[examples/serde_extract](../../examples/serde_extract/README.md).
