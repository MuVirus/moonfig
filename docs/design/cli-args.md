# Command-line arguments (CliSource)

> **Conclusion**: one `CliSource` uses only one value style; short options must be registered, repeated arguments must be declared as arrays, and positional arguments map by declaration.
> **Authority**: Normative — the contract from argv to config keys follows this document; implementation details follow `cli_source/`.
> **Out of scope**: Full code is in [examples/](../../examples/README.md); history is in [decisions.md](../decisions/decisions.md).

`CliSource` reads the process's argv into a config tree. It does not go through `Format` and does not touch files; the input is the argument list, the output is a `Layer`.
Type inference is shared with `EnvSource` through `Value::from_literal`, rules in [sources.md](sources.md#six-kinds-of-source).

## Input and result

| Input | Style and declaration | Parse result |
|---|---|---|
| `--db.port=6543 --debug` | `Equals` (default) | `db.port = 6543`, `debug = true` |
| `--db.port 6543 --debug` | `Separate` | `db.port = 6543`, `debug = true` |
| `--db.port=6543` | `Separate` | `ParseError`, never switches style automatically |
| `-p=5432 -vq` | `Equals` + register `p→db.port`, `v→verbose`, `q→quiet` | `db.port = 5432`, `verbose = true`, `quiet = true` |
| `--tag a --tag b` | `Separate` + `with_array("tag")` | `tag = ["a", "b"]` |
| `--a=1 --a.b=2` | `Equals` (default) | `ParseError`, no config produced |

Which path a short option lands on is set at registration time; a long option's key name is itself the path. The following sections explain why these results are defined this way.

## One source uses one value style

Choose one of two styles, fixed at construction; the default is `Equals`, and
`with_value_style(CliValueStyle::Separate)` switches to the other:

- `Equals` (default): the value follows `=`, as in `--key=value`, or `-p=value` for short options.
- `Separate`: the value is the next argument, as in `--key value`, or `-p value` for short options.

They never both apply. Under `Separate`, writing `--key=value` raises `ParseError` directly; under `Equals`, writing
`-p value` for a registered short option also errors.

**Why not accept both**: the same argv also carries the program's own arguments, and without a long-option registry there is no way to tell whether
`positional` in `--flag positional` is a value or a program argument. With the style fixed, splitting is deterministic and config keys cannot
silently swallow positional arguments. Under `Equals`, `--key value` can only mean "switch + positional argument" — a bare `--key` is a valid boolean switch
in both styles, and must not be treated as an error.

**`Separate` boundaries**: a value starting with `-` is taken as the next option, so use `Equals` with `--key=-1` for negative numbers;
a lone `-` still works as a value. Everything after `--` is positional. This style suits the case where the whole command line is config:
the program's own `--key=value` also raises a style error, so put it after `--`, or use `Equals`.

## Positional arguments map by declaration

Positional arguments do not enter config by default; to turn a subcommand or file path into a config key, declare it with
`with_positional(index, key)` in the order of "non-option arguments":

| Position | key |
|---|---|
| 0 | `command` |
| 1 | `model` |

```text
Input (Separate): moonfmi simulate model.fmu --start 0 --stop 10 --step 0.01

Result: command = "simulate", model = "model.fmu", start = 0, stop = 10, step = 0.01
```

Positions count only non-option arguments: options themselves and the values they eat are skipped, and everything after `--` counts as positional. `new()` does not count the executable
file name; `from_args` treats the whole table as arguments by default, and skips element 0 when `program_name=true` is passed.

Under the default `Equals`, `--start 0` only yields `start = true`, and `0` is a positional argument that does not follow the option; such a
CLI needs `Separate`.

Undeclared positions do not error and do not produce empty keys; when the same key is mapped from several positions, the later declaration wins, and declaring it as an array accumulates
in order. Positional values are also guessed by literal: `model.fmu` is a string, while `0` in a position is an Int.

Origin labels use the original argv index (`cli:argv[1]`), without the value. When you need the original list of positional arguments, still read
`@env.args()` or the `args` field. Values after an unregistered short option may still count as positional arguments; program arguments are best placed
after `--`.

## Short options must be registered

`with_short_option` registers a short option that takes a value, `with_short_flag` registers a boolean switch. Unregistered short options are ignored as program
arguments. Long options have no registry; `--key` is always a config argument, and bare it is a switch.

The value syntax follows the current style, and `-p5432` or the other syntax is not accepted additionally: one style has exactly one way to split.
Boolean short options can be chained (`-vq`); switches take no value, use `--no-key` for false.

**Why register**: short options collide with the program's own arguments too easily; only what the author explicitly declared counts as config.

## Repeated arguments must be declared as arrays explicitly

`with_array("tag")` declares a path as an array. After declaring, writing the same argument several times collects the values in order; writing it once still gives a
single-element array.

**Why not automatic**: undeclared repeated keys keep "the later one wins", the usual way to overwrite config. Collecting arrays automatically would change that
existing semantics. **Why not swallow several values at once**: `--tag a b c` cannot be told apart from the program's own positional arguments; express plurals by repeating the
argument.

Arrays and hierarchy block each other (declaring `tag` and also writing `--tag.x=1`) and raise an error rather than guessing a winner.

## Nesting, conflicts and origins

Both `-` and `.` in argument names split into hierarchy, keys are lowercased; `_` is an ordinary character.

When a scalar occupies a hierarchy name, or an array is used as a hierarchy, raise `ParseError` and name the argument, never silently dropping values.

The whole layer shares one site, looking the original argument name back up by path; labels write only the argument name, never the value, so passwords do not leak into
logs through origin tracking. The site interface is in [sources.md](sources.md#origin-tracking).

## Code location

The implementation lives in `cli_source/`. `core/` does not touch argv or the process environment, so this layer is its own package; package layout rules are in
[sources.md](sources.md#package-layout-and-naming).
