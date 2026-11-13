# Source and package layout

> **Conclusion**: `Source` owns "where to read from"; `Format` owns "how to parse"; the origin object rides on `Value` for tracking.
> **Authority**: Normative — interface responsibilities, package boundaries and origin semantics follow this document; signatures follow `.mbti`.
> **Out of scope**: Steps are in [layer-sources.md](../guides/layer-sources.md); history is in [decisions.md](../decisions/decisions.md).

Two layers of interface, each with one job:

- `Source` owns "where to read from", producing one config layer and that layer's origins (`Layer`).
- `Format` owns "how to parse", decoding a piece of bytes into a `Value`.

`Source` is a trait defined in `core/`:

```moonbit
pub(open) trait Source {
  fn collect(Self) -> Layer raise ConfigError
  fn kind(Self) -> SourceKind = _   // defaults to Custom
  fn raw_locator(Self) -> &Locator? = _   // defaults to None; used by hot reload
}

pub struct Layer {
  value : Value
  origin : &OriginSite?
}
```

`Config::add` only accepts `Source`; by default it merges in insertion order, rules in [design.md](design.md#3-config-object-and-getters).
`Source::kind` feeds `ByKind` ordering without calling `collect` first. `Source::raw_locator` serves hot reload:
a file source returns a re-readable `Locator`, so even if its keys are overwritten by a later source, editing the file still triggers a reread; see
[hot-reload.md](hot-reload.md#what-counts-as-a-change).

## Six kinds of Source

- `MemorySource`: a `Value` already built in the program, for defaults and for testing merge rules.
- `StringSource`: a piece of text + a `Format`.
- `BytesSource`: a piece of bytes + a `Format`.
- `FileSource`: a path + a `Format`; reads the file itself.
- `EnvSource`: reads process environment variables.
- `CliSource`: reads command-line arguments.

There is no `JsonSource` or `TomlSource` type. They are just "a string + some format", and `StringSource` plus `JsonFormat` is enough; wrapping another Source per format would only keep mixing "format" and "where to read from".

`EnvSource` and `CliSource` do not use `Format`: their input is key-value pairs and argv, not a piece of text or bytes.
They guess types like `dotenv_format`, but the guessing must be shared across packages, so the core provides `Value::from_literal`:

```moonbit
pub fn Value::from_literal(StringView) -> Value raise ConfigError
```

`true` / `false` → `Bool`, integers → `Int64`, anything with a decimal point or exponent → `Float`, the rest → string;
an integer outside `Int64` raises `ParseError`, never silently degrading. Type inference must finish at this layer: by the time values are read into structs,
the standard library's `Bool::from_json` / `Double::from_json` reject strings.

`EnvSource` rules: only variables with the given prefix are read, and the prefix is not part of the key; both `_` and `.` count as hierarchy, and keys are lowercased;
the whole layer shares one site, which stores a "path → variable name" index, so `origin_of("db.port")` can point at
`APP_DB_PORT`. If a scalar occupies a hierarchy name, or two variables land on the same path, it raises `ParseError` rather than guessing a winner by traversal order.

`CliSource` parsing rules (value style, short options, arrays, conflicts) are in [cli-args.md](cli-args.md).

## What goes in `core/`

Only the four traits `Source`, `Format`, `Locator` and `OriginSite`, the three implementations `MemorySource`, `StringSource` and `BytesSource`, plus `LiveConfig` for hot reload. `LiveConfig` reads bytes only through `Locator` and never calls platform APIs directly; `FileSource`, `EnvSource` and `CliSource` define no extra marker traits, each implements `Source` in its own package; `FileSource` additionally implements `OriginSite` and `Locator`.

The three implementations in `core/` are pure computation, touch no IO, and compile on every target; every format package needs `StringSource` / `BytesSource` anyway, so keeping them in `core/` avoids writing a copy each time.

`FileSource` reads files, `EnvSource` reads the process environment and `CliSource` reads argv, all with platform constraints; `EnvSource` adds a whole set of rules for prefixes, separators, nested keys and type inference. Putting them in `core/` would break "`core/` has no platform code".

## Package layout and naming

- `core/`: the core package, four traits, three in-memory implementations, and `LiveConfig`.
- `core/format/xxx_format/`: provides only a `Format` type, such as `JsonFormat` or `TomlFormat`, with no extra `Source` wrapper. Dependencies go in its own `moon.pkg`; adding a format touches only this package.
- `file_source/`, `env_source/`, `cli_source/`: `Source` implementations, at the same level as `core/`.

The suffix says what the package provides: format packages use `_format`, Source packages use `_source`. This also avoids clashing with MoonBit standard library package names (`env` and `json` both clashed before); the reason is in [decisions.md](../decisions/decisions.md#1-package-names-cannot-collide-with-moonbit-standard-library-package-names).

## When to use a third-party parser

There is no hard rule. If a parser is mature, pleasant to use, brings no platform dependency and fits the `core/` constraints, use it directly; otherwise, or when the format is simple and writing it yourself gives more control, write it yourself.

TOML, YAML, XML and CBOR use third-party parsers; JSON, INI and `.env` are written in-house.

## Origin tracking

Tracking information rides on every node of `Value`: a node stores an `&OriginSite?`, not a label string, and no separate
"path → origin" table is built. When a table is overwritten by a scalar or an array is replaced as a whole, no stale data is left behind.

```moonbit
pub(all) enum SourceKind { Memory; File; Env; Cli; Custom }

pub(open) trait OriginSite {
  fn kind(Self) -> SourceKind
  fn describe(Self, KeyPath) -> String
  fn locator(Self) -> &Locator? = _   // defaults to None
}

pub(open) trait Locator {
  fn read(Self) -> Bytes raise ConfigError
}
```

`describe` receives a `KeyPath`, so environment variables and the command line can look the original name back up by path; file sources ignore the path
and report only the file itself. `OriginSite` is a trait object and `Value` carries just one more reference; labels are generated at query time, not stored as a snapshot.

`Value` gains a private field `origin : &OriginSite?`, which constructors set to `None`. `Source::collect` produces
`Layer`, handing the value and this layer's site to `Config` together:

```moonbit
pub(open) trait Source {
  fn collect(Self) -> Layer raise ConfigError
  fn kind(Self) -> SourceKind = _   // blanket impl gives Custom
  fn raw_locator(Self) -> &Locator? = _   // defaults to None; used by hot reload
}
```

`Format` is not tagged — the same `JsonFormat` may parse an in-memory string or a file, and it does not know its location.
It instead offers three default methods, `suffixes` / `sniff` / `decode_path`, letting each format declare its suffixes and content traits;
automatic detection is in [format-detect.md](format-detect.md).

`Config::merged` fills sites into the whole tree recursively after each `collect()`, then merges; `build` clearing `sources`
loses no information. When merging, the site follows the winner, and table nodes take the overwriting side's site. Nodes that already have a site are not overwritten,
so composite sources can use `Value::with_origin` to tag subtrees with different sites first.

### Display and reverse lookup

`label` is for humans only; it neither parses nor reverse-engineers. Queries return `Origin`, which is "site + path":

- `Config::origin_of(path) -> Origin? raise ConfigError`
- `Config::origin_at(path : KeyPath) -> Origin? raise ConfigError`
- `Config::origins() -> Array[Origin] raise ConfigError`, with paths computed during traversal, not stored in nodes
- `Config::snapshot() -> Array[Entry] raise ConfigError`, each entry with its path, value and origin

`Origin` methods: `kind()`, `label()`, `path()`, `locator()`, `site()`. `path()` gives a structured
`KeyPath` (`segments()` / `to_string()`), so programmatic checks can look at segments directly instead of splitting strings.

`Config::snapshot()` exports the current tree as `Array[Entry]`, each entry "path + value + origin", mapping to
`path()` / `value()` / `origin()`. Table nodes recurse, arrays are leaves, sharing the same traversal with `origins()`;
when an origin is not tracked, `origin()` gives `None` rather than faking a label.

Both queries merge on the spot when `build()` has not run, hence the `raise`; `origin_of` gives `None` when the path does not exist.
`StringSource` / `BytesSource` report `SourceKind::Custom`, with labels `string` / `bytes`.

`FileSource` is the site of its own layer and also implements `Locator`: `label()` is `file:<path>`,
and `locator()` calls `read()` once to reread the same bytes. Its `raw_locator()` also returns itself,
so hot reload can track file sources that were overwritten. A failed file read raises `ConfigError::IoError`, with the path and
underlying reason in the message; a parse failure is still `ParseError`.

The environment and command-line sites store a "path → original variable name / argument name" index: `describe(path)` builds
`env:APP_DB_PORT` / `cli:--log-level`; table nodes fall back to `env:prefix*` / `cli:args` when lookup fails.
The index comes from the variables or argv actually read this time, not from formatted labels.

`MemorySource` uses a separate empty site and does not return itself: `MemorySource` holds the value tree, and pointing back would create a cycle.
native's default reference counting does not collect cycles (`MOONBIT_TRIAL_DELETION=0`); only JS / wasm-gc tracing GC does.

`&T` in MoonBit is a trait object, usable only for traits, not Rust's borrow; there are no lifetime checks.
So `Origin` can safely hold a site, but `&Path` does not work (`Path` is a struct), and core cannot reference a concrete type with
`&` either.

`FileSource`'s path is just `String`, matching the `moonbitlang/x/fs` interface. `@path` could technically enter core,
but it would drag in platform dispatch; `Path` is only a `String` wrapper and `@fs` accepts only `String`. When path arithmetic is needed, use `Path`
inside the `file_source` package; core's site stays `String`.

Do not use `String?` as an origin: consumers would have to test `starts_with("file:")`, and a typo in the prefix or a missing parse would never error;
trait object + enum gives exhaustive matching.

`Value`'s `Eq` must be written by hand to compare only `kind`, otherwise two values with the same content but different origins are not equal.

One semantic limitation: a table node's site is "the layer that touched it last", so reverse lookup is only accurate for leaves; a full history would require changing
`origin` from a single site into a list.

## Cross-package API

Methods cannot cross packages; capabilities that do become free functions: `to_json(v)`, `extract_from(cfg, path)`. When designing new APIs, prefer free functions over methods. Records are in [decisions.md](../decisions/decisions.md#2-methods-cannot-cross-packages).
