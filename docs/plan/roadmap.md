# moonfig roadmap

Records "in what order things are done, and what acceptance each part has when
done". Not a contract; it can change at any time. The roadmap table in the README
is the public summary, and its statuses and entries stay in sync with this
document.

Design docs: [docs/design/design.md](../design/design.md).

Status has three levels: ✅ done (in maintenance), 🚧 in progress, ⬜ not started.

---

## Core　✅

**Direction**: Configuration exists only in memory — one representation, merge by key, read by key. It touches no external environment, so it compiles on every target.

- [x] `Value` / `ValueKind`: one representation covering configuration values of every format
- [x] Dotted-path reads
- [x] Merge rules: merge by key, arrays replaced wholesale
- [x] `Config` builder with `get_string` / `get_int` / `get_bool` / `get_float`
- [x] Error handling: `MissingKey` / `TypeMismatch` / `ParseError`
- [x] Struct reads (`FromConfig` / `derive(FromJson)`)
- [x] Origin tracking: `origin_of` / `origins` show which layer a key finally came from, see [sources.md](../design/sources.md#origin-tracking)

### Follow-ups

The core features are done; the item below is a maintenance-period enhancement.

- [ ] Value errors carry origins (`TypeMismatch` still has three fields)

Tracking is already on `Value` and `Config`; writing origins into value error messages would change the shape of `ConfigError`, so it waits until the error types are settled together.

### Initial implementation order

| Step | Content | Acceptance |
|---|---|---|
| 1 | `value.mbt` + `error.mbt` | construct a few `Value`s and check the `debug_inspect` shape |
| 2 | `merge.mbt` | nested `Table` verifies "later overwrites earlier, tables merge key by key, arrays replaced wholesale" |
| 3 | `source.mbt` + `config.mbt` | two `MemorySource`s merged, `get_*` reads values; a missing key reports `MissingKey` |
| 4 | `core/format/json_format/` | `Json` text → `Value`, `Int` / `Float` separated by whether there is a decimal point |
| 5 | `extract` | large integers survive end to end |

After steps 1–3 the library is usable (only `MemorySource` exists for now). Steps 4 and 5 are independent increments.

---

## Many formats　✅

**Direction**: Read configuration in every format into the same `Value`. Formats can be swapped freely without changing declarations.

- [x] JSON text (`core/format/json_format/` package)
- [x] TOML (`MuVirus/moonfig-toml` module, `toml_format/` package, depends on `moonbit-community/toml`)
- [x] YAML (`MuVirus/moonfig-yaml` module, `yaml_format/` package, depends on `moonbit-community/yaml`)
- [x] `.env` text (`core/format/dotenv_format/` package)
- [x] INI (`core/format/ini_format/` package)
- [x] XML (`MuVirus/moonfig-xml` module, `xml_format/` package, depends on `Milky2018/xml`)
- [x] CBOR (`MuVirus/moonfig-cbor` module, `cbor_format/` package, depends on `2515050242/cbor`)

Each new format does one thing only: format → `Value`. Merging, reading and validation all reuse `core/`, with no second implementation per format.

**A format describes how the content is written; a Source describes where it is read from.** An `.env` file is a format, environment variables are a Source, and the two are done separately: `EnvSource` does not need to know which format the environment variables will eventually become when it reads them.

**CBOR is a binary format, small in size, common on MCUs.** It is also a good test of `Value`'s representational power — and the result of that test was that `Value` was missing one shape. CBOR has byte strings, and `Value` had nowhere to put them, so `ValueKind` now has a `Bytes` branch, and `get_bytes` extracts it as-is. Everything else lines up one to one: integers, strings, arrays and maps need no special case.

**Cost**: YAML, TOML, XML and CBOR all depend on third-party parsers (`moonbit-community/yaml`, `moonbit-community/toml`, `Milky2018/xml`, `2515050242/cbor`). A module's dependencies are the union of what all its packages import, so a package boundary alone would still make every user download every parser. Each of the four therefore ships as its own module (`modules/moonfig-<name>/` in the repository, `MuVirus/moonfig-<name>` on mooncakes), and `moon add MuVirus/moonfig` stays a dependency on `moonbitlang/x` only.

**JSON, INI and `.env` all use hand-written parsers with no third-party dependency.** All three only use MoonBit standard library packages: JSON goes through `@json`, INI and `.env` go through `parse_int64` / `parse_double` in `@string`. INI's type guessing is documented in the package doc comment: sections become levels, quotes force a string, and `;` and `#` only count as comments at the start of a line; `.env`'s rules are in the package docs too: the `export` prefix is optional, `.` in key names becomes a level, single quotes are kept as-is, double quotes interpret escapes, `#` only starts a trailing comment when preceded by whitespace, and there is no variable expansion.

**YAML syntax is delegated to `moonbit-community/yaml`; this library only converts `Yaml` → `Value`.** The package docs state the boundaries: only one document is accepted; an empty file, an empty document, a file with only comments, or a file whose root node is `null` yields an empty table; the root node is usually expected to be a mapping; integers beyond `Int64` error rather than silently degrading to floats.

**TOML syntax is delegated to `moonbit-community/toml`; this library only converts `TomlValue` → `Value`.** The package docs state the boundaries: the root node must be a table; an array mixing different types errors (TOML requires homogeneous arrays); date-times have no corresponding shape in `Value` and are stored as strings from their original text; large integers stay `Int64`.

**XML syntax is delegated to `Milky2018/xml`; this library only converts the element tree → `Value`.** XML has no notion of "key/value", and the mapping rules are this library's, written in the package docs: the root element is just a shell and its children land at the top level; sibling elements with the same name become an array; attributes go on keys with the `@` prefix; mixed content goes on `#text`; CDATA is literal text and always a string (which is also XML's own way of saying "I want a string").

**CBOR syntax is delegated to `2515050242/cbor`; this library only converts `CborValue` → `Value`.** The package docs state the boundaries: the root node must be a map; map keys must be text strings (CBOR allows integer keys, but configuration keys are paths, paths are text, and integer keys error instead of being quietly converted to strings — that way integer key `1` would collide with string key `"1"`); tags are stripped and only the value inside is kept (`Value` has nowhere to put a tag); `undefined` errors (it is not the same thing as `null`, and `null` becomes `Value::null()`); byte strings are kept as-is in `Value::bytes` and `get_bytes` retrieves the raw bytes; integers beyond `Int64` error rather than silently degrading to floats; half and single precision floats both widen to `Double`.

---

## External Source　✅

**Direction**: Read the outside world into configuration. IO happens only here; the `core/` layer sees no files or environment variables.

- [x] `FileSource`: read configuration files, with the format decided by the layer above
- [x] `EnvSource`: read environment variables
- [x] `CliSource`: read command-line arguments
- [x] Any combination of multiple Sources, with priority determined by insertion order

### Environment variables are the most treacherous part of this section

Environment variables are all strings:

- **Type inference must be finished at this step** (`"5432"` → `Int`, `"true"` → `Bool`). Waiting until the struct read step is too late — the standard library's `Bool::from_json` and `Double::from_json` both reject strings.
  - How it lands: `core` provides `Value::from_literal`, shared by `EnvSource` / `CliSource` instead of each writing its own.
- The separator convention has to be decided: does `_` become `.`? Is it case sensitive?
  - How it lands: both `_` and `.` count as levels, and key names are uniformly lowercased; two variables differing only in case that land on the same path error.
- How prefixes, empty values and list values are handled.
  - How it lands: the prefix is given at construction (`EnvSource::all()` reads everything); an empty value is the empty string; lists are not split and the whole string stays a string.

---

## Validation　✅

**Direction**: Validate configuration on the way in, so problems surface at startup rather than halfway through business code.

- [x] Missing required fields
- [x] Range validation (port ranges, string length limits)
- [x] Whether unknown keys error, as a switch
- [x] Validation rules written by users themselves
- [x] Validation failures give the key name, expected value and actual value

**How it lands**: a rule table for keys, `Validate` for structs, both paths sharing `ConfigError` and the check functions. Required fields rely on `MissingKey`; unknown keys rely on `Rule::allowed_keys` (no check when not written). See [validate.md](../design/validate.md).

---

## Format detection　✅

**Direction**: Given a file, read it without specifying a format. Design in [format-detect.md](../design/format-detect.md).

- [x] Decide by suffix (`.json` / `.toml` / `.yaml`)
- [x] Decide by content when the suffix is missing or unreliable
- [x] Error when detection fails, listing the supported formats
- [x] Give position and reason when parsing fails

**How it lands**: `Format` declares its own `suffixes` / `sniff` / `decode_path`; `Detector` normalizes suffixes, checks duplicate declarations and does content detection in candidate order; `FileSource::auto` hands the path and bytes to the detector. When parsing fails for a known suffix, it errors directly without trying another candidate.

---

## Hot reload (polling)　✅

**Direction**: When a configuration file changes it takes effect again without restarting the process. Design in [hot-reload.md](../design/hot-reload.md).

- [x] Watch file changes: compare file content, not mtime
- [x] Re-read and re-merge
- [x] Notify the consumer through a callback
- [x] Keep the old configuration when the new one fails to parse or validate

**How it lands**: `build_live()` keeps the source list, and `reload()` replaces the snapshot only on success; `hot_reload`'s `watch()` registers callbacks, and the caller drives one round of checks with `Watcher::poll()`. `interval` is only a suggestion; the library has no built-in timer.

**Follow-ups**:

- [ ] Built-in timer or OS file events (inotify / kqueue / ReadDirectoryChangesW)
- [ ] Watching changes to environment variables and the command line; there are no reliable events yet, so `reload()` is still manual

---

## Future directions　⬜

- [ ] Remote configuration support: fetch configuration files over HTTP/URL, with timeout retries and a local fallback.
- [ ] Encrypted storage: encrypted parsing and secure storage of sensitive configuration fields.
- [ ] Preprocessed data: process existing configuration text or data without changing the source data.

---

## Dependencies

```text
Core ──→ Many formats ──→ External Source ──→ Format detection ──→ Hot reload
  │
  └──→ Validation
```

"Validation" and "Many formats" do not block each other; either can be done first. "Format detection" only makes sense once there is more than one format.

How the documentation system changes is in [doc-system.md](doc-system.md).
