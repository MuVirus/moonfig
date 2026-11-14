// Blackbox tests run against the package's public API.
// 手写结构体提取（FromConfig + Getter）：标签改名、缺省值、可选、容器、
// 嵌套、错误路径。Getter 只在 from_config 里出现，测试都从
// `to_struct` / `get_struct` 入口走。

///|

///|
/// 嵌套结构体：host 用了改名标签，port 是原生 64 位
struct DbCfg {
  host : String
  port : Int64
}

///|
impl @config.FromConfig for DbCfg with fn from_config(get : @config.Getter) -> DbCfg raise @config.ConfigError {
  {
    host: get.string("db-host"), // 标签改名
    port: get.int("port"), // 原生 Int64，不用 Int64Text
  }
}

///|
/// 全字段形状：默认值、可选、数组、嵌套
struct ServerCfg {
  host : String
  port : Int64
  retry : Int32
  ratio : Double?
  tags : Array[String]
  debug : Bool
  db : DbCfg
}

///|
impl @config.FromConfig for ServerCfg with fn from_config(get : @config.Getter) -> ServerCfg raise @config.ConfigError {
  {
    host: get.string("db-host"),
    port: get.int("port"),
    retry: get.int32_or("retry", 3),
    ratio: get.opt_float("ratio"),
    tags: get.strings("tags"),
    debug: get.bool_or("debug", false),
    db: get.nested("db"),
  }
}

///|
/// 从一个 Value 表构造单来源 Config
fn server_cfg(
  table : @config.Value,
) -> @config.Config raise @config.ConfigError {
  @config.Config::new().add(@config.MemorySource::new(table)).build()
}

///|
fn server_error(table : @config.Value) -> String {
  try {
    let _ : ServerCfg = server_cfg(table).get_struct("server")
    "no error"
  } catch {
    error => error.to_string()
  }
}

///|
/// 全字段提取：改名标签、缺省值、可选、数组、嵌套一起工作
test "get_struct extracts with tags, defaults, options and nesting" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("localhost"),
      "port": @config.Value::int(5432L),
      "tags": @config.Value::array([
        @config.Value::str("a"),
        @config.Value::str("b"),
      ]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("inner"),
        "port": @config.Value::int(6543L),
      }),
    }),
  })
  let got : ServerCfg = server_cfg(table).get_struct("server")
  assert_eq(got.host, "localhost")
  assert_eq(got.port, 5432L)
  assert_eq(got.retry, 3) // 没写 retry，落默认值
  assert_eq(got.ratio, None) // 没写 ratio，None
  assert_eq(got.tags, ["a", "b"])
  assert_false(got.debug) // 没写 debug，落默认值
  assert_eq(got.db.host, "inner")
  assert_eq(got.db.port, 6543L)
}

///|
/// 缺省字段给值就覆盖默认：`retry`、`debug`，可选字段给 `null` 仍是 None
test "present keys override defaults and null stays None" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(1L),
      "retry": @config.Value::int(5L),
      "ratio": @config.Value::float(2.5),
      "debug": @config.Value::bool(true),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  let got : ServerCfg = server_cfg(table).get_struct("server")
  assert_eq(got.retry, 5)
  assert_eq(got.ratio, Some(2.5))
  assert_eq(got.tags, [])
  assert_true(got.debug)
}

///|
/// 可选浮点的整数来源按浮点加宽
test "opt_float widens integer sources" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(1L),
      "ratio": @config.Value::int(3L),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  let got : ServerCfg = server_cfg(table).get_struct("server")
  assert_eq(got.ratio, Some(3.0))
}

///|
/// 缺失必填键：错误带完整前缀
test "missing required key reports the full path" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "port": @config.Value::int(1L),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  assert_eq(
    server_error(table),
    "missing key 'server.db-host': no source provides it",
  )
}

///|
/// 类型不符：字符串来源不能变整数，浮点来源不能截断
test "type mismatch reports key, expected and actual" {
  let with_string = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::str("5432"),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  assert_eq(
    server_error(with_string),
    "key 'server.port': expected Int, got Str",
  )

  let with_float = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::float(3.14),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  assert_eq(
    server_error(with_float),
    "key 'server.port': expected Int, got Float",
  )
}

///|
/// 键存在但越界：默认值救不了，照常报错
test "int32 overflow errors even with a default" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(1L),
      "retry": @config.Value::int(3000000000L),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  assert_eq(
    server_error(table),
    "parse error: key 'server.retry' is out of range for Int32",
  )
}

///|
/// 数组元素类型错：错误路径带下标
test "array element errors carry the index" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(1L),
      "tags": @config.Value::array([
        @config.Value::str("a"),
        @config.Value::int(5L),
      ]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::int(2L),
      }),
    }),
  })
  assert_eq(server_error(table), "key 'server.tags.1': expected Str, got Int")
}

///|
/// 嵌套结构体的错误路径逐级加深
test "nested errors deepen the path" {
  let table = @config.Value::table({
    "server": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(1L),
      "tags": @config.Value::array([]),
      "db": @config.Value::table({
        "db-host": @config.Value::str("d"),
        "port": @config.Value::str("x"),
      }),
    }),
  })
  assert_eq(server_error(table), "key 'server.db.port': expected Int, got Str")
}

///|
/// 64 位精确性：9007199254740993 超出 Double 精确范围，这条路径直接读
/// `Int` 节点，不走 Json，原文不丢
test "int64 stays exact without Int64Text" {
  let table = @config.Value::table({
    "db": @config.Value::table({
      "db-host": @config.Value::str("h"),
      "port": @config.Value::int(9007199254740993L),
    }),
  })
  let got : DbCfg = server_cfg(table).get_struct("db")
  assert_eq(got.port, 9007199254740993L)
}

///|
/// `float_strict` 不加宽：整数来源报类型不符
struct RatioCfg {
  ratio : Double
}

///|
impl @config.FromConfig for RatioCfg with fn from_config(get : @config.Getter) -> RatioCfg raise @config.ConfigError {
  { ratio: get.float_strict("ratio"), }
}

///|
fn ratio_error(table : @config.Value) -> String {
  try {
    let _ : RatioCfg = table.to_struct()
    "no error"
  } catch {
    error => error.to_string()
  }
}

///|
test "float_strict rejects integer sources" {
  assert_eq(
    ratio_error(@config.Value::table({ "ratio": @config.Value::int(1L) })),
    "key 'ratio': expected Float, got Int",
  )
  let ok : RatioCfg = @config.Value::table({
    "ratio": @config.Value::float(1.5),
  }).to_struct()
  assert_eq(ok.ratio, 1.5)
}

///|
/// `uint64` 只收非负整数来源，64 位内精确
struct BigCfg {
  big : UInt64
}

///|
impl @config.FromConfig for BigCfg with fn from_config(get : @config.Getter) -> BigCfg raise @config.ConfigError {
  { big: get.uint64("big"), }
}

///|
test "uint64 rejects negative and reads exact" {
  let got : BigCfg = @config.Value::table({
    "big": @config.Value::int(9007199254740993L),
  }).to_struct()
  assert_eq(got.big, 9007199254740993UL)
  let message = try {
    let _ : BigCfg = @config.Value::table({ "big": @config.Value::int(-1L) }).to_struct()
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "parse error: key 'big' is out of range for UInt64")
}

///|
/// `@config.Value::to_struct` 原语：标签相对该值解析，前缀为空
test "to_struct extracts a subtree directly" {
  let value = @config.Value::table({
    "db-host": @config.Value::str("h"),
    "port": @config.Value::int(5432L),
  })
  let got : DbCfg = value.to_struct()
  assert_eq(got.host, "h")
  assert_eq(got.port, 5432L)
}

///|
/// 分层来源照常工作：get_struct 读的是合并后的树
test "get_struct reads the merged tree" {
  let defaults = @config.MemorySource::new(
    @config.Value::table({
      "server": @config.Value::table({
        "db-host": @config.Value::str("default"),
        "port": @config.Value::int(1L),
        "tags": @config.Value::array([]),
        "db": @config.Value::table({
          "db-host": @config.Value::str("inner"),
          "port": @config.Value::int(2L),
        }),
      }),
    }),
  )
  let overrides = @config.MemorySource::new(
    @config.Value::table({
      "server": @config.Value::table({
        "db-host": @config.Value::str("override"),
      }),
    }),
  )
  let cfg = @config.Config::new().add(defaults).add(overrides).build()
  let got : ServerCfg = cfg.get_struct("server")
  assert_eq(got.host, "override")
  assert_eq(got.db.host, "inner")
}

///|
/// `get_struct_validated`：提取后跑结构体自己的 `Validate`
struct RangedDb {
  port : Int64
}

///|
impl @config.FromConfig for RangedDb with fn from_config(get : @config.Getter) -> RangedDb raise @config.ConfigError {
  { port: get.int("port"), }
}

///|
impl @config.Validate for RangedDb with fn validate(
  self : RangedDb,
  prefix : @config.KeyPath,
) -> Unit raise @config.ConfigError {
  @config.check_int_range(prefix.add("port"), self.port, 1L, 65535L)
}

///|
test "get_struct_validated runs the struct's Validate" {
  let cfg = server_cfg(
    @config.Value::table({
      "db": @config.Value::table({ "port": @config.Value::int(70000L) }),
    }),
  )
  let message = try {
    let _ : RangedDb = cfg.get_struct_validated("db")
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(
    message, "invalid value for key 'db.port': expected 1..65535, got 70000",
  )
}

///|
/// 逃生舱：`value` 拿原始 `Value` 自己 match，`opt_value` 缺失和 null 都是 None
struct RawCfg {
  payload : @config.Value
  absent : @config.Value?
}

///|
impl @config.FromConfig for RawCfg with fn from_config(get : @config.Getter) -> RawCfg raise @config.ConfigError {
  { payload: get.value("payload"), absent: get.opt_value("absent"), }
}

///|
test "raw value escape hatch keeps the original node" {
  let got : RawCfg = @config.Value::table({ "payload": @config.Value::int(7L) }).to_struct()
  assert_eq(got.payload.kind.name(), "Int")
  assert_eq(got.absent, None)
}
