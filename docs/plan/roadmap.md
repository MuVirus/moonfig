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

The core features are done; the items below are maintenance-period enhancements.

- [ ] Error origin lookup: `origin_of_error(cfg, err)` returns the layer behind a `ConfigError`, without changing the error variants
- [ ] Structured parse errors: keep the parser's reason and position as fields, render only in `Show`
- [ ] Value errors carry positions: `TypeMismatch` / `InvalidValue` still have no source span; needs a per-node source map

**Design sketch (structured parse errors)**:

- `SourcePosition`: `Text(line, column)` for text formats, `Bytes(offset)` for binary ones.
- `ParseError(String)` becomes `ParseError(String, SourcePosition?)`; `Show` renders `parse error at line L, column C: ...` or `at byte N: ...`. This is a breaking change to `ConfigError`, taken once before 1.0.
- The position comes from the format; the source label (`file:...`) stays separate. Build-time file parse errors get `file '<path>': ` from `FileSource` first; a uniform `At(label, error)` wrapper is decided when this item starts.
- Coverage: JSON / INI / .env / XML first; TOML / YAML depend on their parser; CBOR byte offsets wait for upstream `CborError` to carry a position.

**Acceptance**:

- Origin lookup: after `catch`, a key-bearing error resolves to `file:...` / `env:...`; a build-time file parse error includes `file '<path>': `; `Show` text is unchanged.
- Structured parse errors: `catch` reads the position field directly without parsing the message; JSON / INI / .env / XML each have a test; `Show` matches `errors.md`. TOML / YAML depend on their parser; CBOR offsets are not part of the acceptance.
- Value-error positions: not started; no acceptance until the source-map design exists.

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
- Separator convention: which characters split, whether `_` becomes `.`, and case sensitivity.
  - How it lands: only `.` splits by default; `with_separator("_")` opts into `_`, and `with_separator("__")` keeps single underscores literal. Key names are lowercased; two variables differing only in case that land on the same path error.
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

## Remote configuration　⬜

**Direction**: Treat a remote endpoint as a Source, not as "a URL downloader". Network IO still happens only in the Source layer; what comes back is bytes or key/value pairs, and parsing, merging, validation, origin tracking and hot reload all reuse the existing paths.

**Tiers** (ordered by how common the capability is in other configuration libraries, not by what MoonBit already has):

| Tier | Scope | Acceptance |
|---|---|---|
| 1 | Generic HTTP/HTTPS file source: a URL plus an optional format, auth headers, timeout and retry, conditional requests and a local cache. Also covers Git raw files, Spring Cloud Config (an `Environment` response plus a thin mapping), and object storage reached through a signed or public URL. | A remote file works end to end: `ETag` / `Last-Modified`, timeout and retry, cache fallback when offline, and `origin` naming the URL and revision; a parse or validation failure keeps the old snapshot. |
| 2 | Remote KV / configuration centers with change notification: etcd, Consul, ZooKeeper, Nacos, Apollo, Firestore, NATS and Kubernetes ConfigMap / Secret. Key, prefix, namespace / group / profile reads; watch, long polling or blocking queries; local snapshot and auth. | A shared KV + watch abstraction works with at least one general KV (etcd or Consul) and one configuration center (Nacos or Apollo): local snapshot, monotonic revision, `origin` with key and revision, and the old snapshot kept when a refresh fails. |
| 3 | Cloud parameter and secret services: AWS SSM Parameter Store / AppConfig / Secrets Manager, Azure App Configuration / Key Vault, GCP Runtime Config / Secret Manager, Vault / CredHub. Cloud IAM, signing or OAuth, resource hierarchies, versions / labels and secret semantics. | At least one cloud service reads a parameter and a secret through its native auth, with version / label selection and redaction in errors and `origin`. |
| 4 | Storage-backed and feature-flag sources: S3 / GCS / Blob / OSS SDK semantics, Redis, SQL, MongoDB; LaunchDarkly / Unleash / Flagsmith / OpenFeature. Mostly storage or runtime targeting rather than static configuration. | Decided only after tiers 1–3: either an adapter over an existing client, or explicitly left out when the `Value` / `Source` model cannot represent it cleanly. |

Why this order:

- Viper's remote providers are etcd / etcd3, Consul, Firestore and NATS, with `WatchRemoteConfig`; that is tier 2.
- Spring Cloud Config's client is HTTP (tier 1); its server backends include Git, Vault, JDBC, Redis, S3, AWS SSM and GCP Secret Manager, which is where the later tiers come from.
- Apollo and Nacos make namespace / group, long polling and a local snapshot standard; Kubernetes ConfigMap / Secret is the cloud-native KV + watch.
- Cloud parameter and secret services add IAM, signing and secret semantics, so they follow the generic KV abstraction.
- Feature flags are runtime targeting plus streaming updates, not static configuration; keep them out until the model needs them.

Shared capabilities, whichever remote is used:

- [ ] Local cache and fallback: persist the last successful snapshot and use it at startup when the remote is unreachable; distinguish "the cache is stale" from "there is no cache".
- [ ] Refresh strategy: polling with conditional requests, long polling / SSE / watch; a monotonic revision prevents an old response from overwriting newer configuration; keep the old configuration on failure.
- [ ] Timeouts and retries: exponential backoff with jitter, a configurable cap, cancellation; separate retryable failures (5xx / network) from non-retryable ones (4xx / auth).
- [ ] Authentication and secrets: read tokens from the environment or a keychain, never from the configuration file; redact sensitive values in logs, errors and `origin`.
- [ ] Consistency and integrity: TLS verification, revision / checksum / signature checks; validate before replacing the snapshot.
- [ ] Traceable origins: `origin` reports the remote kind, URL / key, revision and fetch time; merge with local layers in insertion order.
- [ ] Testability: our own transport trait wraps the client, so tests never touch the real network; platform backends (JS `fetch`, native, wasm) are separate packages.

**How it lands (draft)**: tier 1 adds `http_source/` (or a separate module); the `Source` produces a `Layer`, and the format is left to `Format` / `Detector`. Tier 2 adds a watch-capable Source abstraction and reuses `Locator` / `LiveConfig` for caching and snapshot replacement; each provider is an adapter. A remote response becomes `Bytes` or key/value pairs first, then goes through the existing parse and validation path; no second merge implementation for remote sources.

**HTTP client**: the official `moonbitlang/async/http` is enough for tier 1; no third-party client is needed. It covers native, wasm1 and js (verified on Windows native), so the remote source lives in its own module rather than in `MuVirus/moonfig`: the dependency tree (`async`, `tls` through OpenSSL, `socket`, `gzip`) is heavy and the API is still experimental, and `core/` must stay dependency-free. The package declares `supported_targets = "+native,+wasm,+js"` because async has no wasm-gc support, and `moon check --target all` then skips it instead of failing. `Source::collect` stays synchronous: an async `fetch()` fills a cache and `collect()` returns it, so merging, validation and hot reload keep their current shapes. The client only performs the request; retry, backoff, conditional requests, cache persistence and `origin` remain ours to write.

**Open design questions**:

- Which shape the async entry point takes: the caller drives `HttpSource::fetch()` inside a runtime and `collect()` only reads the cache; whether an async facade (`fetch_all()` / `reload_async()`) is also needed is left to tier 1. wasm-gc has no async support, so the remote module either skips that target or offers cache reads only.
- Should protocol adapters sit on one generic HTTP Source (a configuration center is just a different URL plus a parser), or should each center get its own Source? The latter is preferred, because authentication, pagination and watch semantics differ a lot.
- For tier 2, does watch belong in `Source`, or in a separate `Watcher` trait? `LiveConfig` currently polls `Locator`; a push-based watch needs a different shape.
- Are feature flags configuration? They behave more like "runtime reads plus streaming updates"; leave them out for now and revisit when the `Value` / `Source` model needs them.

**Acceptance**: tier 1 is the entry point for the whole direction; tiers 2–4 are independent increments, each with its acceptance in the table above.

---

## Future directions　⬜

- [ ] Encrypted storage: encrypted parsing and secure storage of sensitive configuration fields.
- [ ] Preprocessed data: process existing configuration text or data without changing the source data.

---

## Dependencies

```text
Core ──→ Many formats ──→ External Source ──→ Format detection ──→ Hot reload
  │
  └──→ Validation
```

"Validation" and "Many formats" do not block each other; either can be done first. "Format detection" only makes sense once there is more than one format. Remote configuration builds on External Source and Format detection; its refresh path reuses Hot reload.

How the documentation system changes is in [doc-system.md](doc-system.md).
