// Blackbox tests run against the package's public API.
// 这里只测核心自己：合并、取值、错误。
// 凡是和具体格式有关的（JSON）都去 `json/` 包测。

///|
using @config {
  type BytesSource,
  type Config,
  type ConfigError,
  type MemorySource,
  type MergeRule,
  type MergeStrategy,
  type SourceKind,
  type StringSource,
  type Value,
  type ValueKind,
}

///|
/// 用户侧最小的用法：两个 MemorySource 合起来取值
test "merge later source wins, tables merge per key" {
  let defaults = MemorySource::new(
    Value::table({
      "db": Value::table({
        "host": Value::str("localhost"),
        "port": Value::int(5432L),
      }),
      "debug": Value::bool(false),
    }),
  )
  let overrides = MemorySource::new(
    Value::table({ "db": Value::table({ "port": Value::int(6543L) }) }),
  )
  let cfg = Config::new().add(defaults).add(overrides).build()
  assert_eq(cfg.get_string("db.host"), "localhost") // 来自 defaults，没被覆盖
  assert_eq(cfg.get_int("db.port"), 6543L) // 来自 overrides，后加的赢
  assert_false(cfg.get_bool("debug")) // 只有 defaults 提供，保持 false
}

///|
/// array整体替换，不拼接
test "array is replaced, not concatenated" {
  let base = MemorySource::new(
    Value::table({ "hosts": Value::array([Value::str("a"), Value::str("b")]) }),
  )
  let over = MemorySource::new(
    Value::table({ "hosts": Value::array([Value::str("c")]) }),
  )
  let cfg = Config::new().add(base).add(over).build()
  assert_eq(cfg.get_value("hosts").kind, ValueKind::Array([Value::str("c")]))
}

///|
/// 缺 key 报 MissingKey，并把路径原样带出来
test "missing key raises MissingKey" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "db": Value::table({ "host": Value::str("localhost") }) }),
      ),
    )
    .build()
  let message = try {
    ignore(cfg.get_string("db.user"))
    "no error"
  } catch {
    ConfigError::MissingKey(path) => "missing \{path}"
    e => e.to_string()
  }
  assert_eq(message, "missing db.user")
}

///|
/// 类型不对报 TypeMismatch：哪个键、期望什么、实际什么都要说清楚
test "wrong type raises TypeMismatch" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "db": Value::table({ "host": Value::str("localhost") }) }),
      ),
    )
    .build()
  let message = try {
    ignore(cfg.get_int("db.host"))
    "no error"
  } catch {
    ConfigError::TypeMismatch(path, expected, actual) =>
      "\{path}: expected \{expected}, got \{actual}"
    e => e.to_string()
  }
  assert_eq(message, "db.host: expected Int, got Str")
}

///|
/// 每个取值函数都要说清楚自己期望什么
test "getters report expected and actual" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "n": Value::int(1L), "s": Value::str("x") }),
      ),
    )
    .build()
  assert_eq(
    type_error_of("Str", () => ignore(cfg.get_string("n"))),
    "n: expected Str, got Int",
  )
  assert_eq(
    type_error_of("Int", () => ignore(cfg.get_int("s"))),
    "s: expected Int, got Str",
  )
  assert_eq(
    type_error_of("Bool", () => ignore(cfg.get_bool("s"))),
    "s: expected Bool, got Str",
  )
  assert_eq(
    type_error_of("Float", () => ignore(cfg.get_float("s"))),
    "s: expected Float, got Str",
  )
  assert_eq(
    type_error_of("Bytes", () => ignore(cfg.get_bytes("s"))),
    "s: expected Bytes, got Str",
  )
}

///|
/// get_float 默认把整数加宽成浮点；严格模式仍然只收 Float
test "get_float widens Int and get_float_strict does not" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "int": Value::int(5432L),
          "float": Value::float(0.5),
          "str": Value::str("1"),
        }),
      ),
    )
    .build()
  assert_eq(cfg.get_float("float"), 0.5)
  assert_eq(cfg.get_float("int"), 5432.0)
  assert_eq(
    type_error_of("Float", () => ignore(cfg.get_float_strict("int"))),
    "int: expected Float, got Int",
  )
  assert_eq(
    type_error_of("Float", () => ignore(cfg.get_float("str"))),
    "str: expected Float, got Str",
  )
}

///|
/// byte string原样取出来
test "get_bytes returns the raw bytes" {
  let cfg = Config::new()
    .add(
      MemorySource::new(Value::table({ "blob": Value::bytes(b"\x01\x02\xff") })),
    )
    .build()
  assert_eq(cfg.get_bytes("blob"), b"\x01\x02\xff")
}

///|
/// 测试用的格式：把字节原样当字符串，不做解析
struct EchoFormat {}

///|
impl @config.Format for EchoFormat with fn decode(_ : EchoFormat, bytes : Bytes) -> Value raise ConfigError {
  let text = @utf8.decode(bytes) catch {
    _ => raise ConfigError::ParseError("invalid UTF-8")
  }
  Value::str(text)
}

///|
/// text先编码成字节，再交给格式
test "StringSource encodes text before decoding" {
  let source = StringSource::new("hello", EchoFormat::{ })
  assert_eq(@config.Source::collect(source).value, Value::str("hello"))
}

///|
/// 字节原样交给格式
test "BytesSource passes bytes through" {
  let source = BytesSource::new(b"hi", EchoFormat::{ })
  assert_eq(@config.Source::collect(source).value, Value::str("hi"))
}

///|
/// 跑一段注定报错的代码，把 `TypeMismatch` 拼成一句话
fn type_error_of(expected : String, f : () -> Unit raise ConfigError) -> String {
  try {
    f()
    "no error"
  } catch {
    ConfigError::TypeMismatch(path, e, actual) =>
      if e == expected {
        "\{path}: expected \{e}, got \{actual}"
      } else {
        "expected \{expected}, got \{e}"
      }
    e => e.to_string()
  }
}

///|
/// 测试用的来源：值和来源对象都自己给
struct KindedSite {
  kind : SourceKind
  label : String
}

///|
impl @config.OriginSite for KindedSite with fn kind(self : KindedSite) -> SourceKind {
  self.kind
}

///|
impl @config.OriginSite for KindedSite with fn describe(
  self : KindedSite,
  _ : @config.KeyPath,
) -> String {
  self.label
}

///|
struct KindedSource {
  value : Value
  site : &@config.OriginSite
}

///|
pub impl @config.Source for KindedSource with fn collect(self : KindedSource) -> @config.Layer {
  @config.Layer::new(self.value, Some(self.site))
}

///|
pub impl @config.Source for KindedSource with fn kind(self : KindedSource) -> SourceKind {
  @config.OriginSite::kind(self.site)
}

///|
fn kinded(value : Value, kind : SourceKind, label : String) -> KindedSource {
  let site : &@config.OriginSite = KindedSite::{ kind, label, }
    as &@config.OriginSite
  KindedSource::{ value, site, }
}

///|
/// 来源跟着赢家走：后加的来源覆盖了 db.port，来源就是后加的那层
test "origin_of follows the winning layer" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "db": Value::table({
            "host": Value::str("localhost"),
            "port": Value::int(5432L),
          }),
        }),
      ),
    )
    .add(
      MemorySource::new(
        Value::table({ "db": Value::table({ "port": Value::int(6543L) }) }),
      ),
    )
    .build()
  let origin = cfg.origin_of("db.port").unwrap()
  assert_eq(origin.kind(), SourceKind::Memory)
  assert_eq(origin.label(), "memory")
  assert_eq(origin.path().to_string(), "db.port")
  assert_true(cfg.origin_of("db.user") is None)
}

///|
/// origins() 列出叶子路径，表节点不算叶子
test "origins lists every leaf" {
  let cfg = Config::new()
    .add(
      kinded(
        Value::table({
          "db": Value::table({ "host": Value::str("localhost") }),
          "debug": Value::bool(false),
        }),
        SourceKind::File,
        "file:config/app.json",
      ),
    )
    .build()
  let origins = cfg.origins()
  assert_eq(origins.length(), 2)
  let labels = origins.map(fn(origin) {
    "\{origin.path().to_string()}=\{origin.label()}"
  })
  assert_true(labels.contains("db.host=file:config/app.json"))
  assert_true(labels.contains("debug=file:config/app.json"))
}

///|
/// 错误的键能查回来源；没有键、没有来源或路径穿过标量时给 None
test "origin_of_error resolves the layer behind key errors" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "db": Value::table({
            "host": Value::str("localhost"),
            "extra": Value::int(1L),
          }),
        }),
      ),
    )
    .build()
  let origin = @config.origin_of_error(
    cfg,
    ConfigError::TypeMismatch("db.host", "Int", "Str"),
  ).unwrap()
  assert_eq(origin.label(), "memory")
  assert_eq(origin.path().to_string(), "db.host")
  assert_true(
    @config.origin_of_error(
      cfg,
      ConfigError::InvalidValue("db.host", "1..64 characters", "0 characters"),
    )
    is Some(_),
  )
  assert_true(
    @config.origin_of_error(cfg, ConfigError::UnknownKey("db.extra")) is Some(_),
  )
  assert_true(
    @config.origin_of_error(
      cfg,
      ConfigError::MergeConflict("db.host", "Str", "Int"),
    )
    is Some(_),
  )
  assert_true(
    @config.origin_of_error(cfg, ConfigError::MissingKey("db.user")) is None,
  )
  assert_true(
    @config.origin_of_error(cfg, ConfigError::ParseError("bad")) is None,
  )
  assert_true(@config.origin_of_error(cfg, ConfigError::IoError("bad")) is None)
  assert_true(
    @config.origin_of_error(cfg, ConfigError::UnknownFormat("x", [])) is None,
  )
}

///|
/// 路径穿过标量时没有可报告的来源
test "origin_of_error returns none when the path crosses a scalar" {
  let cfg = Config::new()
    .add(MemorySource::new(Value::table({ "db": Value::str("x") })))
    .build()
  assert_true(
    @config.origin_of_error(
      cfg,
      ConfigError::TypeMismatch("db.host", "Int", "Str"),
    )
    is None,
  )
}

///|
/// 来源不同不算值不同
test "value equality ignores origin" {
  let from_memory = Config::new()
    .add(MemorySource::new(Value::table({ "k": Value::str("x") })))
    .build()
    .get_value("k")
  let from_file = Config::new()
    .add(
      kinded(
        Value::table({ "k": Value::str("x") }),
        SourceKind::File,
        "file:config.json",
      ),
    )
    .build()
    .get_value("k")
  assert_eq(from_memory, from_file)
}

///|
/// FirstWins：先加的赢，后加只补空缺
test "FirstWins keeps the earlier value" {
  let cfg = Config::new()
    .add(MemorySource::new(Value::table({ "a": Value::int(1L) })))
    .add(MemorySource::new(Value::table({ "a": Value::int(2L) })))
    .with_rule(MergeRule::FirstWins)
    .build()
  assert_eq(cfg.get_int("a"), 1L)
}

///|
/// ByKind：array里越靠前越优先，同一档内后加的赢
test "ByKind ranks sources by kind" {
  let env = kinded(
    Value::table({ "a": Value::int(3L) }),
    SourceKind::Env,
    "env:A",
  )
  let file = kinded(
    Value::table({ "a": Value::int(2L) }),
    SourceKind::File,
    "file:a",
  )
  let memory = kinded(
    Value::table({ "a": Value::int(1L) }),
    SourceKind::Memory,
    "memory",
  )
  let env_wins = Config::new()
    .add(memory)
    .add(file)
    .add(env)
    .with_rule(MergeRule::ByKind([SourceKind::Env, SourceKind::File]))
    .build()
  assert_eq(env_wins.get_int("a"), 3L)
  let memory_wins = Config::new()
    .add(memory)
    .add(file)
    .add(env)
    .with_rule(MergeRule::ByKind([SourceKind::Memory]))
    .build()
  assert_eq(memory_wins.get_int("a"), 1L)
}

///|
/// Custom：函数拿到的前一个是已经合好的部分
test "Custom rule decides the merge" {
  let cfg = Config::new()
    .add(MemorySource::new(Value::table({ "a": Value::int(1L) })))
    .add(MemorySource::new(Value::table({ "a": Value::int(2L) })))
    .with_rule(MergeRule::Custom(fn(base, _over) { base }))
    .build()
  assert_eq(cfg.get_int("a"), 1L)
}

///|
/// Append：声明路径两侧都是数组时拼接，配置层在前、命令行在后
test "Append concatenates declared list keys" {
  let file = kinded(
    Value::table({
      "simulate": Value::table({ "set": Value::array([Value::str("a")]) }),
    }),
    SourceKind::File,
    "file:app.toml",
  )
  let cli = kinded(
    Value::table({
      "simulate": Value::table({ "set": Value::array([Value::str("b")]) }),
    }),
    SourceKind::Cli,
    "cli:--set",
  )
  let cfg = Config::new()
    .add(file)
    .add(cli)
    .with_strategy("simulate.set", MergeStrategy::Append)
    .build()
  assert_eq(
    cfg.get_value("simulate.set"),
    Value::array([Value::str("a"), Value::str("b")]),
  )
  let origin = cfg.origin_of("simulate.set").unwrap()
  assert_eq(origin.kind(), SourceKind::Cli)
  assert_eq(origin.label(), "cli:--set")
}

///|
/// 没声明的路径仍是整体替换；显式 Replace 与不声明一致
test "Replace keeps the overwrite behavior" {
  let layers = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("a")]) }),
      ),
    )
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("b")]) }),
      ),
    )
  assert_eq(layers.build().get_value("set"), Value::array([Value::str("b")]))
  assert_eq(
    layers.with_strategy("set", MergeStrategy::Replace).build().get_value("set"),
    Value::array([Value::str("b")]),
  )
}

///|
/// Union：拼接后按首次出现去重
test "Union dedups keeping the first occurrence" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "connect": Value::array([Value::str("a"), Value::str("b")]),
        }),
      ),
    )
    .add(
      MemorySource::new(
        Value::table({
          "connect": Value::array([Value::str("b"), Value::str("c")]),
        }),
      ),
    )
    .with_strategy("connect", MergeStrategy::Union)
    .build()
  assert_eq(
    cfg.get_value("connect"),
    Value::array([Value::str("a"), Value::str("b"), Value::str("c")]),
  )
}

///|
/// Append 下 null 算缺席：没给的那层让位，给过的保留
test "null counts as absent under a declared strategy" {
  let kept = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("a")]) }),
      ),
    )
    .add(MemorySource::new(Value::table({ "set": Value::null() })))
    .with_strategy("set", MergeStrategy::Append)
    .build()
  assert_eq(kept.get_value("set"), Value::array([Value::str("a")]))
  let filled = Config::new()
    .add(MemorySource::new(Value::table({ "set": Value::null() })))
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("b")]) }),
      ),
    )
    .with_strategy("set", MergeStrategy::Append)
    .build()
  assert_eq(filled.get_value("set"), Value::array([Value::str("b")]))
}

///|
/// 声明了策略的路径两侧类型不符，build 抛 MergeConflict
test "declared list keys raise MergeConflict on type mismatch" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("a")]) }),
      ),
    )
    .add(MemorySource::new(Value::table({ "set": Value::str("b") })))
    .with_strategy("set", MergeStrategy::Append)
  let message = try {
    ignore(cfg.build())
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "merge conflict at key 'set': Array vs Str")
}

///|
/// 策略与 ByKind 组合：拼接顺序跟处理顺序走，优先级低的在前
test "Append order follows the merge rule order" {
  let memory = kinded(
    Value::table({ "set": Value::array([Value::str("m")]) }),
    SourceKind::Memory,
    "memory",
  )
  let env = kinded(
    Value::table({ "set": Value::array([Value::str("e")]) }),
    SourceKind::Env,
    "env",
  )
  let cli = kinded(
    Value::table({ "set": Value::array([Value::str("c")]) }),
    SourceKind::Cli,
    "cli",
  )
  let cfg = Config::new()
    .add(memory)
    .add(env)
    .add(cli)
    .with_rule(MergeRule::ByKind([SourceKind::Cli, SourceKind::Env]))
    .with_strategy("set", MergeStrategy::Append)
    .build()
  // ByKind 的处理顺序：没列出的 Memory 最先，然后 Env，最后 Cli
  assert_eq(
    cfg.get_value("set"),
    Value::array([Value::str("m"), Value::str("e"), Value::str("c")]),
  )
}

///|
/// 多个路径各声明各的策略，互不影响
test "strategies can be declared per key" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "set": Value::array([Value::str("a")]),
          "connect": Value::array([Value::str("x")]),
        }),
      ),
    )
    .add(
      MemorySource::new(
        Value::table({
          "set": Value::array([Value::str("a")]),
          "connect": Value::array([Value::str("x"), Value::str("y")]),
        }),
      ),
    )
    .with_strategy("set", MergeStrategy::Append)
    .with_strategy("connect", MergeStrategy::Union)
    .build()
  assert_eq(
    cfg.get_value("set"),
    Value::array([Value::str("a"), Value::str("a")]),
  )
  assert_eq(
    cfg.get_value("connect"),
    Value::array([Value::str("x"), Value::str("y")]),
  )
}

///|
/// Custom 自己接管合并，策略对它不生效
test "Custom rule ignores declared strategies" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("a")]) }),
      ),
    )
    .add(
      MemorySource::new(
        Value::table({ "set": Value::array([Value::str("b")]) }),
      ),
    )
    .with_rule(MergeRule::Custom(fn(_base, over) { over }))
    .with_strategy("set", MergeStrategy::Append)
    .build()
  assert_eq(cfg.get_value("set"), Value::array([Value::str("b")]))
}

///|
/// 不追踪来源的来源：`Layer::untracked`
struct QuietSource {
  value : Value
}

///|
pub impl @config.Source for QuietSource with fn collect(self : QuietSource) -> @config.Layer {
  @config.Layer::untracked(self.value)
}

///|
test "source without origin reports none" {
  let source = QuietSource::{ value: Value::table({ "a": Value::int(1L) }), }
  assert_true(@config.Source::collect(source).origin is None)
  let cfg = Config::new().add(source).build()
  assert_true(cfg.origin_of("a") is None)
}

///|
/// text和字节来源都归到 `Custom`，标签说明是哪种
test "StringSource and BytesSource report their labels" {
  let text_layer = @config.Source::collect(
    StringSource::new("hello", EchoFormat::{ }),
  )
  let text_site = text_layer.origin.unwrap()
  assert_eq(@config.OriginSite::kind(text_site), SourceKind::Custom)
  assert_eq(
    @config.OriginSite::describe(text_site, @config.KeyPath::root()),
    "string",
  )
  let bytes_layer = @config.Source::collect(
    BytesSource::new(b"hi", EchoFormat::{ }),
  )
  let bytes_site = bytes_layer.origin.unwrap()
  assert_eq(@config.OriginSite::kind(bytes_site), SourceKind::Custom)
  assert_eq(
    @config.OriginSite::describe(bytes_site, @config.KeyPath::root()),
    "bytes",
  )
}

///|
/// origins() 把array当叶子，不再往里拆下标
test "origins treats arrays as leaves" {
  let cfg = Config::new()
    .add(
      kinded(
        Value::table({
          "hosts": Value::array([Value::str("a"), Value::str("b")]),
        }),
        SourceKind::File,
        "file:hosts.json",
      ),
    )
    .build()
  let origins = cfg.origins()
  assert_eq(origins.length(), 1)
  let origin = origins[0]
  assert_eq(origin.path().to_string(), "hosts")
  assert_eq(origin.label(), "file:hosts.json")
}

///|
/// 表节点的来源是最后碰它的那层，没被覆盖的叶子仍归原层
test "table node origin follows the overriding layer" {
  let cfg = Config::new()
    .add(
      kinded(
        Value::table({
          "db": Value::table({
            "host": Value::str("localhost"),
            "port": Value::int(5432L),
          }),
        }),
        SourceKind::File,
        "file:base.json",
      ),
    )
    .add(
      kinded(
        Value::table({ "db": Value::table({ "port": Value::int(6543L) }) }),
        SourceKind::Env,
        "env:DB_PORT",
      ),
    )
    .build()
  let db = cfg.origin_of("db").unwrap()
  assert_eq(db.label(), "env:DB_PORT")
  let host = cfg.origin_of("db.host").unwrap()
  assert_eq(host.label(), "file:base.json")
}

///|
/// 路径穿过标量：origin_of 和「路径不存在」一样给 None
test "origin_of returns none when the path crosses a scalar" {
  let cfg = Config::new()
    .add(MemorySource::new(Value::table({ "a": Value::int(1L) })))
    .build()
  let result = try {
    match cfg.origin_of("a.b") {
      None => "no origin"
      Some(_) => "unexpected origin"
    }
  } catch {
    e => "unexpected error: \{e}"
  }
  assert_eq(result, "no origin")
}

///|
/// 字面量猜类型：环境变量和命令行共用这一套
test "Value::from_literal infers bool, int, float and string" {
  assert_eq(Value::from_literal("true").kind, ValueKind::Bool(true))
  assert_eq(Value::from_literal("false").kind, ValueKind::Bool(false))
  assert_eq(Value::from_literal("5432").kind, ValueKind::Int(5432L))
  assert_eq(Value::from_literal("-7").kind, ValueKind::Int(-7L))
  assert_eq(Value::from_literal("0.5").kind, ValueKind::Float(0.5))
  assert_eq(Value::from_literal("1e2").kind, ValueKind::Float(100.0))
  assert_eq(Value::from_literal("localhost").kind, ValueKind::Str("localhost"))
  assert_eq(Value::from_literal("").kind, ValueKind::Str(""))
  assert_eq(Value::from_literal("1.2.3").kind, ValueKind::Str("1.2.3"))
}

///|
/// 不完整的数字形状仍然是字符串，不会误判成 Int/Float
test "Value::from_literal keeps incomplete numeric shapes as strings" {
  assert_eq(Value::from_literal("-").kind, ValueKind::Str("-"))
  assert_eq(Value::from_literal("1.").kind, ValueKind::Str("1."))
  assert_eq(Value::from_literal("1e").kind, ValueKind::Str("1e"))
  assert_eq(Value::from_literal("2e+3").kind, ValueKind::Float(2000.0))
  assert_eq(Value::from_literal("-0.5e1").kind, ValueKind::Float(-5.0))
}

///|
/// integer超出 `Int64` 时报错，不静默降级成浮点或字符串
test "Value::from_literal reports integer overflow" {
  let message = try {
    ignore(Value::from_literal("99999999999999999999"))
    "no error"
  } catch {
    ConfigError::ParseError(message) => message
    e => e.to_string()
  }
  assert_true(message.contains("Int64"))
}

///|
/// 扁平可选取值：缺失或 `null` 都是 `None`，其余按各自类型读
test "optional getters return None for missing or null keys" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "db": Value::table({ "port": Value::int(5432L) }),
          "name": Value::str("app"),
          "debug": Value::bool(true),
          "ratio": Value::float(0.5),
          "cert": Value::bytes(b"ab"),
          "nulled": Value::null(),
        }),
      ),
    )
    .build()
  assert_eq(cfg.get_opt_string("name"), Some("app"))
  assert_eq(cfg.get_opt_bool("debug"), Some(true))
  assert_eq(cfg.get_opt_int("db.port"), Some(5432L))
  assert_eq(cfg.get_opt_int32("db.port"), Some(5432))
  assert_eq(cfg.get_opt_uint64("db.port"), Some(5432UL))
  assert_eq(cfg.get_opt_float("ratio"), Some(0.5))
  assert_eq(cfg.get_opt_bytes("cert"), Some(b"ab"))
  assert_eq(cfg.get_opt_string("missing"), None)
  assert_eq(cfg.get_opt_int("nulled"), None)
}

///|
/// 扁平可选取值仍守严格性：整数加宽浮点，类型不符和越界照常报错
test "optional getters keep widening and range rules" {
  let cfg = Config::new()
    .add(
      MemorySource::new(
        Value::table({
          "count": Value::int(3L),
          "text": Value::str("5432"),
          "big": Value::int(3000000000L),
          "negative": Value::int(-1L),
        }),
      ),
    )
    .build()
  assert_eq(cfg.get_opt_float("count"), Some(3.0))
  let wrong_type = try {
    ignore(cfg.get_opt_int("text"))
    "no error"
  } catch {
    e => e.to_string()
  }
  assert_eq(wrong_type, "key 'text': expected Int, got Str")
  let int32 = try {
    ignore(cfg.get_opt_int32("big"))
    "no error"
  } catch {
    e => e.to_string()
  }
  assert_eq(int32, "parse error: key 'big' is out of range for Int32")
  let uint64 = try {
    ignore(cfg.get_opt_uint64("negative"))
    "no error"
  } catch {
    e => e.to_string()
  }
  assert_eq(uint64, "parse error: key 'negative' is out of range for UInt64")
}
