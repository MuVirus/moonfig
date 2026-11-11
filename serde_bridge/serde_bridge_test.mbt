// Blackbox tests run against the package's public API.
// moonfig `Value` 的 serde 后端：类型侧手写 `Deserialize`（serde 用户既有
// 代码的形态，手写或由 serde 的 derive 生成器生成均可），moonfig 只消费
// trait。测试从 `extract_serde` / `extract_serde_from` / `serde_field` 入口走。

///|
using @config {type Config, type ConfigError, type MemorySource, type Value}

///|
/// 手写 Deserialize：struct 协议 + `required` 收尾，serde 用户代码的标准形态
struct SerdePoint {
  x : Int32
  y : Int32
  label : String?
}

///|
impl @serde.Deserialize for SerdePoint with fn deserialize(d) -> SerdePoint raise @serde.DeError {
  d.deserialize_struct_begin("SerdePoint", ["x", "y", "label"])
  let mut f_x = None
  let mut f_y = None
  let mut f_label = None
  while d.deserialize_field_name() is Some(name) {
    match name {
      "x" => f_x = Some(d.deserialize_field_value())
      "y" => f_y = Some(d.deserialize_field_value())
      "label" => f_label = d.deserialize_field_value()
      _ => d.skip_value()
    }
  }
  {
    x: @serde.required(f_x, name="x", path=d.path()),
    y: @serde.required(f_y, name="y", path=d.path()),
    label: f_label,
  }
}

///|
/// 标签改名：类型决定自己认哪些配置键
struct SerdeRetry {
  retries : Int32
}

///|
impl @serde.Deserialize for SerdeRetry with fn deserialize(d) -> SerdeRetry raise @serde.DeError {
  d.deserialize_struct_begin("SerdeRetry", ["max-retries"])
  let mut f = None
  while d.deserialize_field_name() is Some(name) {
    match name {
      "max-retries" => f = Some(d.deserialize_field_value())
      _ => d.skip_value()
    }
  }
  { retries: @serde.required(f, name="max-retries", path=d.path()), }
}

///|
/// 嵌套结构体 + 容器（`Array[T]` 用 serde 的 blanket impl）
struct SerdeApp {
  name : String
  port : Int64
  tags : Array[String]
  db : SerdePoint
}

///|
impl @serde.Deserialize for SerdeApp with fn deserialize(d) -> SerdeApp raise @serde.DeError {
  d.deserialize_struct_begin("SerdeApp", ["name", "port", "tags", "db"])
  let mut f_name = None
  let mut f_port = None
  let mut f_tags = None
  let mut f_db = None
  while d.deserialize_field_name() is Some(name) {
    match name {
      "name" => f_name = Some(d.deserialize_field_value())
      "port" => f_port = Some(d.deserialize_field_value())
      "tags" => f_tags = Some(d.deserialize_field_value())
      "db" => f_db = Some(d.deserialize_field_value())
      _ => d.skip_value()
    }
  }
  {
    name: @serde.required(f_name, name="name", path=d.path()),
    port: @serde.required(f_port, name="port", path=d.path()),
    tags: @serde.required(f_tags, name="tags", path=d.path()),
    db: @serde.required(f_db, name="db", path=d.path()),
  }
}

///|
/// 枚举：unit 变体是 `Str`，带载荷的是单条目 Table（外部标签）
enum SerdeMode {
  Off
  Rate(Int32)
}

///|
impl @serde.Deserialize for SerdeMode with fn deserialize(d) -> SerdeMode raise @serde.DeError {
  let index = d.deserialize_enum_begin("SerdeMode", ["Off", "Rate"])
  let mode = match index {
    0 => {
      d.deserialize_unit_variant()
      SerdeMode::Off
    }
    1 => SerdeMode::Rate(d.deserialize_newtype_variant())
    _ =>
      raise @serde.DeError::DeCustom(
        path=d.path(),
        message="variant index out of range",
      )
  }
  d.deserialize_enum_end()
  mode
}

///|
fn app_error(table : Value) -> String {
  try {
    let _ : SerdeApp = @serde_bridge.extract_serde(table)
    "no error"
  } catch {
    error => error.to_string()
  }
}

///|
/// 端到端：改名标签、嵌套、数组、可选一起工作，未知键跳过
test "extract_serde reads a config tree through serde" {
  let value = Value::table({
    "name": Value::str("app"),
    "port": Value::int(5432L),
    "tags": Value::array([Value::str("a"), Value::str("b")]),
    "db": Value::table({
      "x": Value::int(1L),
      "y": Value::int(2L),
      "label": Value::str("primary"),
      "extra": Value::str("skipped"),
    }),
  })
  let got : SerdeApp = @serde_bridge.extract_serde(value)
  assert_eq(got.name, "app")
  assert_eq(got.port, 5432L)
  assert_eq(got.tags, ["a", "b"])
  assert_eq(got.db.x, 1)
  assert_eq(got.db.y, 2)
  assert_eq(got.db.label, Some("primary"))
}

///|
/// 可选字段：缺失和 null 都是 None
test "optional fields accept absent and null" {
  let absent = Value::table({ "x": Value::int(1L), "y": Value::int(2L) })
  let got : SerdePoint = @serde_bridge.extract_serde(absent)
  assert_eq(got.label, None)

  let null_value = Value::table({
    "x": Value::int(1L),
    "y": Value::int(2L),
    "label": Value::null(),
  })
  let with_null : SerdePoint = @serde_bridge.extract_serde(null_value)
  assert_eq(with_null.label, None)
}

///|
/// 标签改名：配置键与字段名解耦
test "renamed tags map config keys to fields" {
  let got : SerdeRetry = @serde_bridge.extract_serde(
    Value::table({ "max-retries": Value::int(5L) }),
  )
  assert_eq(got.retries, 5)
}

///|
/// 缺失必填字段：MissingKey，键名带前缀
test "missing required field reports the full path" {
  let message = app_error(Value::table({ "name": Value::str("app") }))
  assert_eq(message, "missing key 'port': no source provides it")
}

///|
/// 严格类型：字符串来源不能变数字，浮点不能截断
test "numeric fields reject string and float sources" {
  let as_string = Value::table({
    "name": Value::str("app"),
    "port": Value::str("5432"),
    "tags": Value::array([]),
    "db": Value::table({ "x": Value::int(1L), "y": Value::int(2L) }),
  })
  assert_eq(app_error(as_string), "key 'port': expected Int, got Str")

  let as_float = Value::table({
    "name": Value::str("app"),
    "port": Value::float(3.14),
    "tags": Value::array([]),
    "db": Value::table({ "x": Value::int(1L), "y": Value::int(2L) }),
  })
  assert_eq(app_error(as_float), "key 'port': expected Int, got Float")
}

///|
/// 范围检查：32 位越界报 InvalidValue
test "int32 overflow reports invalid value" {
  let value = Value::table({ "x": Value::int(3000000000L), "y": Value::int(1L) })
  let message = try {
    let _ : SerdePoint = @serde_bridge.extract_serde(value)
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "invalid value for key 'x': expected Int, got 3000000000")
}

///|
/// 嵌套错误路径逐级加深，前缀接上提取入口的路径
test "nested errors deepen the path under the extraction prefix" {
  let value = Value::table({
    "srv": Value::table({
      "name": Value::str("app"),
      "port": Value::int(1L),
      "tags": Value::array([]),
      "db": Value::table({ "x": Value::int(1L), "y": Value::str("bad") }),
    }),
  })
  let message = try {
    let _ : SerdeApp = @serde_bridge.extract_serde(value.get_path("srv"))
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'db.y': expected Int, got Str")
}

///|
/// 枚举：unit 变体与外部标签变体
test "enums read unit and externally tagged variants" {
  let off : SerdeMode = @serde_bridge.extract_serde(Value::str("Off"))
  assert_eq(off is SerdeMode::Off, true)

  let rate : SerdeMode = @serde_bridge.extract_serde(
    Value::table({ "Rate": Value::int(5L) }),
  )
  assert_eq(rate is SerdeMode::Rate(5), true)

  let message = try {
    let _ : SerdeMode = @serde_bridge.extract_serde(Value::str("Bogus"))
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "parse error: key '' has unknown variant `Bogus`")
}

///|
/// 按键提取 + 分层来源
test "extract_serde_from reads the merged tree by key" {
  let defaults = MemorySource::new(
    Value::table({
      "srv": Value::table({
        "name": Value::str("default"),
        "port": Value::int(1L),
        "tags": Value::array([]),
        "db": Value::table({ "x": Value::int(1L), "y": Value::int(2L) }),
      }),
    }),
  )
  let overrides = MemorySource::new(
    Value::table({ "srv": Value::table({ "name": Value::str("override") }) }),
  )
  let cfg = Config::new().add(defaults).add(overrides).build()
  let got : SerdeApp = @serde_bridge.extract_serde_from(cfg, "srv")
  assert_eq(got.name, "override")
  assert_eq(got.db.y, 2)
}

///|
/// 与 FromConfig 混搭：手写字段用 Getter，serde 字段一行委托
struct MixedCfg {
  name : String
  point : SerdePoint
}

///|
impl @config.FromConfig for MixedCfg with fn from_config(get : @config.Getter) -> MixedCfg raise ConfigError {
  {
    name: get.string("app-name"),
    point: @serde_bridge.serde_field(get, "point"),
  }
}

///|
test "serde_field delegates a field to serde inside FromConfig" {
  let value = Value::table({
    "app-name": Value::str("mixed"),
    "point": Value::table({ "x": Value::int(3L), "y": Value::int(4L) }),
  })
  let got : MixedCfg = value.to_struct()
  assert_eq(got.name, "mixed")
  assert_eq(got.point.x, 3)
  assert_eq(got.point.y, 4)

  let bad = Value::table({
    "app-name": Value::str("mixed"),
    "point": Value::table({ "x": Value::int(3L) }),
  })
  let message = try {
    let _ : MixedCfg = bad.to_struct()
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "missing key 'point.y': no source provides it")
}
