# Extraction into a struct

> **Conclusion**: Three paths read a configuration subtree into a struct: `FromConfig` is the default, serde (`serde_bridge`) is an optional adapter for types that already carry a serde description, and `derive(FromJson)` is experimental and the last choice.
> **Authority**: Normative — the serde and Json adapter mappings and their error translation follow this document; `FromConfig` semantics follow [from_config.md](from_config.md); signatures follow `.mbti`.
> **Out of scope**: The default path is in [from_config.md](from_config.md); choice steps are in [choose-extraction.md](../guides/choose-extraction.md); history is in [decisions.md](../decisions/decisions.md).

## 1. `FromConfig`

The default path: implement `FromConfig`, write one line per field, and the `Getter` reads `Value` directly, with no JSON round trip and no extra dependency. Labels, defaults and nesting are decided at the call site:

```moonbit nocheck
impl @config.FromConfig for Server with fn from_config(get : @config.Getter) -> Server raise @config.ConfigError {
  { host: get.string("db-host"), port: get.int("port") }
}
let srv : Server = cfg.get_struct("server")
```

Shape, the `Getter` family, strictness and the reason this is the default are in [from_config.md](from_config.md). This path also composes with the two adapters at field level: `json_field` and `serde_field` delegate a single field, so a nested struct can take a different path without rewriting the tree.

## 2. Combining with serde (`serde_bridge`)

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

Dependency note: `serde_bridge` lives in its own module, `MuVirus/moonfig-serde`, which pulls in `moonbit-community/serde.mbt@0.3.1` (which itself depends only on
moonbitlang core, plus parser/async for its derive generator). Users who do not use serde are unaffected: the root `MuVirus/moonfig` module neither depends on it nor on the serde generator, and existing APIs change in no way.

A complete runnable example (type attributes + generator output + three entry points) is in
[examples/serde_extract](../../examples/serde_extract/README.md).

## 3. `derive(FromJson)` (experimental)

This is the last path to reach for. The entry points carry `#alert(experimental, ...)`, so using them emits
`alert_experimental`, and both the API and the strictness probes may change between minor versions. Prefer
[FromConfig](#1-fromconfig); to keep using this adapter, disable the alert with
`warnings = "-alert_experimental"` in `moon.pkg`.

The adapter has three entry points:

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

### Error messages

`derive(FromJson)` throws `JsonDecodeError((JsonPath, String))`, where `JsonPath`'s `Show` is a JSON Pointer (`/db/port`). `extract` looks that path up in the `Value` and translates it into the same error set as `get_*`:

| Situation | Error |
|---|---|
| Missing field (`Missing field port`) | `MissingKey("db.port")` |
| Type mismatch (`Int::from_json: expected number`) | `TypeMismatch("db.port", "Int", "Str")` |
| Integer overflow (`Int::from_json: overflow`) | `ParseError("key 'db.port' is out of range for Int")` |
| Struct declares `Int64` (`expected number in string representation`) | `ParseError("key 'db.port' is a 64-bit integer: declare the struct field as Int64Text or use get_int")` |

The expected type comes from the standard library's message prefix (`String` → `Str`, `Double` → `Float`, `Map` → `Table`), and the actual type is looked up from the `Value`, so names in messages match `get_*`. Variant fields and message text are in [errors.md](../reference/errors.md).
