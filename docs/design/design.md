# moonfig design

> **Conclusion**: The main line is "many Sources → one representation → layered merge → getters / extraction into structs / validation"; build the smallest end-to-end loop that works first.
> **Authority**: Overview — types and function signatures follow `.mbti` and the code; this document explains the data model and the trade-offs.
> **Out of scope**: Steps are in [layer-sources.md](../guides/layer-sources.md); history is in [decisions.md](../decisions/decisions.md).

## 1. Core types

```moonbit
///| Shape of a config value in memory
pub(all) enum ValueKind {
  Null
  Bool(Bool)
  Int(Int64)              // every integer is Int64
  Float(Double)
  Str(String)
  Bytes(Bytes)            // binary data; only binary formats such as CBOR produce it
  Array(Array[Value])
  Table(Map[String, Value])
}

///| A config value
pub struct Value {
  kind : ValueKind
  priv origin : &OriginSite?   // origin object; constructors give None, filled in before merging
}
```

`origin` stores only a reference to an `OriginSite`, not a label string. `OriginSite` is the source's own object,
providing `kind`, `describe(KeyPath)` and an optional `locator`; the label is generated on demand in `Origin::label()`.

`Source::collect` returns `Layer { value, origin }`, so a layer's value and its site are produced together. `Config`
fills the site into the whole tree recursively; nodes that already have a site are not overwritten, so composite
sources can use `Value::with_origin` to tag subtrees with different sites first.

`KeyPath` is a structured key path (`["db", "port"]`); the dotted string is parsed only once at the `origin_of` /
`get_path` API boundary; `origin_of` / `origins()` return `Origin`, with `path()` for the hierarchy and `label()` for
display text.

`Value::from_literal(StringView)` guesses a config value from a piece of literal text (`Bool` / `Int64` / `Float` /
string); environment variables and the command line share this, with rules in [sources.md](sources.md).

## 2. Merge

```moonbit
fn merge(base : Value, over : Value) -> Value
```

Three rules:

- both are `Table` → merge recursively key by key
- otherwise → `over` overwrites `base`
- arrays are replaced **as a whole**, not concatenated

## 3. Config object and getters

`Config` holds three fields, `sources`, `rule` and `value`: `add` only appends, `build` merges the Sources one by one into a tree according to `rule`, and later `get_*` calls read values from that tree by path. It knows nothing about concrete formats, only `Source`.

`MergeRule` defaults to `LastWins` (later additions overwrite earlier ones), and also offers `FirstWins`, `ByKind(Array[SourceKind])` and `Custom(fn)`. The rule belongs to the whole `Config`; there is no per-layer special case — if you need one, wrap the `Source`. For `ByKind` the array is written from highest to lowest priority; unlisted kinds come last, and within the same tier the later addition wins. `Custom(fn)` receives "the part merged so far" and "the next layer" and returns the new part.

```moonbit
let cfg = Config::new()
  .add(MemorySource::new(table))
  .add(StringSource::new(text, JsonFormat::new()))
  .build()                       // merge in order, later additions win

cfg.get_string("db.host")        // String
cfg.get_int("db.port")           // Int64
cfg.get_float("ratio")           // Double
cfg.get_bool("debug")            // Bool
cfg.get_bytes("cert")            // Bytes
```

- Paths expand with dots: `"db.host"` → `Table{"db": Table{"host": ...}}`
- missing key → **error, no default value** (defaults should come from `MemorySource`; that is its job)
- `get_float` widens `Int` to `Double` by default, approximating by floating-point precision beyond 2^53; `get_float_strict` accepts only `Float`. The reverse (`Float` → integer) always errors, never truncates
- `Config::snapshot()` exports `Array[Entry]`, each entry a path, value and origin; `origins()` takes origins from the same traversal. Table nodes recurse, arrays are leaves

To reread automatically when the config file changes, use `build_live()` to keep the source list; see [hot-reload.md](hot-reload.md).

## 4. Errors

`ConfigError` is the only error type crossing the library boundary. Variant fields, trigger conditions and the exact `Show` text live in [errors.md](../reference/errors.md); the enum and its `Show` implementation are in `core/error.mbt`.

The single UX standard: when users see an error, they immediately know **which key, what was expected, what was actual**.

`IoError` and `ParseError` are separate: unreadable and read-but-unparsable are two different things, and mixing them sends users looking at the format.
`MergeConflict` is a reserved variant — current merge rules are all overwrite, with no type-conflict detection.

## Design documents

- [sources.md](sources.md) —— Source / Format model, package layout and origin tracking
- [extract.md](extract.md) —— extraction into a struct: `FromConfig`, serde and the experimental `derive(FromJson)`, adapter Json mapping and error translation
- [from_config.md](from_config.md) —— the default extraction path: `FromConfig`, `Getter` semantics, native `Int64`
- [validate.md](validate.md) —— validation: per-key rule table, struct `Validate`, unknown keys
- [format-detect.md](format-detect.md) —— automatic format detection: suffix first, content sniffing, candidate order
- [hot-reload.md](hot-reload.md) —— hot reload: snapshot replacement, file polling, keep the old config on failure
- [../decisions/decisions.md](../decisions/decisions.md) —— decision records
