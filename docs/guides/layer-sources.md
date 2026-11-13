# Layer multiple sources

Layer defaults, configuration files, environment variables and the command line into one configuration. Later additions override earlier ones, and at the end you can still find out which layer a value came from. For sources and merge rules, see [sources.md](../design/sources.md) and
[design.md](../design/design.md#3-config-object-and-getters).

## When to use it

- One set of configuration keys serves local development, CI and production, with only the sources swapped
- You need a fixed priority of "defaults → file → environment variables → command line"
- When investigating configuration, you need to answer "who provided this value"

## Prerequisites

- moonfig is installed, and `core`, the format packages you use and the Source packages are imported; for installation, see
  [README](../../README.mbt.md#installation)
- File sources need a format: `FileSource::new(path, format)`; to choose automatically by extension or content, use
  `FileSource::auto(path, detector)`
- Environment variable sources need a prefix, such as `APP_`
- Command-line sources recognize only `--key=value` by default; for space separation switch explicitly to `Separate`

## Completion criteria

- `build()` reports no error, and every key can be `get_*`-ed to the expected value
- `origin_of(path)` points out the winning source; overridden layers no longer appear
- Changing a source layer or adjusting the order does not require changing the reading code

## Steps

1. Put the defaults first: `MemorySource` treats a `Value` tree in memory as one layer, so every key has a usable value.
2. Add the file layer: `FileSource::new("config/app.json", JsonFormat::new())`.
3. Add the environment variable layer: `EnvSource::new("APP_")`; `APP_DB_PORT` lands on `db.port`.
4. Add the command-line layer: `CliSource::new()`; `--log-level=debug` lands on `log.level`. Short options and arrays
   must be registered first; for the style, see [cli-args.md](../design/cli-args.md).
5. After `build()`, read values by key; for diagnostics use `origin_of` (find which layer a key came from) or `origins`
   (list all leaf paths).

```moonbit nocheck
let cfg = Config::new()
  .add(MemorySource::new(Value::table({
    "db": Value::table({ "host": Value::str("localhost"), "port": Value::int(5432L) }),
    "log": Value::table({ "level": Value::str("info") }),
  })))
  .add(FileSource::new("config/app.json", JsonFormat::new()))
  .add(EnvSource::new("APP_"))
  .add(CliSource::new())
  .build()

cfg.get_int("db.port")          // if the environment variable gave 6543, this is 6543
cfg.origin_of("db.port")        // Some(env:APP_DB_PORT)
```

## Common pitfalls and next steps

- The order of addition is the priority order; the default is `LastWins`. For the reverse use
  `.with_rule(MergeRule::FirstWins)`; to order by source type use `MergeRule::ByKind`, writing the array from highest to lowest
  priority (such as `[Env, File]`).
- Nested tables merge key by key, arrays are replaced as a whole; arrays do not merge element by element.
- Environment variables treat `_` and `.` as hierarchy; the command line treats `-` and `.` as hierarchy; keys are converted to lowercase uniformly.
- Environment variables and the command line have no type declarations, so content is guessed literally: `6543` is `Int`, `true` is `Bool`,
  everything else is a string.
- The origin of a table node is "the last layer that touched it"; only leaf paths are accurate.
- A missing file reports `IoError`, broken content reports `ParseError`; a failed hot reload keeps the old configuration, see
  [hot-reload.md](../design/hot-reload.md).
- Next step: read a subtree into a struct, see [choose-extraction.md](choose-extraction.md); for a complete four-layer
  demonstration, see [examples/multi_source](../../examples/multi_source/README.md).
