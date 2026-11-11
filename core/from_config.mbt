///|
/// 手写结构体提取的一切都放这里。
///
/// derive(FromJson) 那条路径零样板，但字段名必须与配置键一致、没有默认
/// 值、64 位字段要包 `Int64Text`。这条路径手写 impl，每个字段的 json
/// 标签内联在调用点，顺便直接给出原生 `Int64`：
///
/// 用法（用户侧，示意；编译过的完整例子见 `core/from_config_test.mbt`）：
///
/// ```mbt nocheck
/// struct Server {
///   host : String
///   port : Int64
///   retry : Int32
/// }
///
/// impl FromConfig for Server with fn from_config(get : Getter) -> Server raise ConfigError {
///   {
///     host: get.string("db-host"), // 标签改名：配置键与字段名解耦
///     port: get.int("port"), // 原生 Int64，不用 Int64Text
///     retry: get.int32_or("retry", 3), // 缺省值
///   }
/// }
///
/// test {
///   let cfg = Config::new()
///     .add(
///       MemorySource::new(
///         Value::table({
///           "server": Value::table({
///             "db-host": Value::str("localhost"),
///             "port": Value::int(5432L),
///           }),
///         }),
///       ),
///     )
///     .build()
///   let srv : Server = cfg.get_struct("server")
///   assert_eq(srv.host, "localhost")
///   assert_eq(srv.port, 5432L)
///   assert_eq(srv.retry, 3) // 没写 retry，落默认值
/// }
/// ```
///
/// 两套路径的分工：标签全等于字段名、不需要默认值时用 derive(FromJson)，
/// 一行 derive 就够；需要改名、缺省值、嵌套路径或原生 64 位时才手写
/// `FromConfig`。嵌套结构体若走 derive 路径，字段里用 json_format 的
/// `json_field` 一行委托，不用逐字段手写。
///
/// MoonBit 没有反射，字段和标签的对应关系只能在调用点建立——即使标签
/// 等于字段名，也要写一遍。这是手写换控制力的代价，和 `Validate` impl
/// 逐字段写 `prefix.add(...)` 是同一个模式。
pub(open) trait FromConfig {
  fn from_config(Getter) -> Self raise ConfigError
}

///|
/// 结构体字段读取器，`FromConfig::from_config` 的参数。
///
/// 绑定一棵子树和它的完整路径前缀：标签是相对子树的点分路径
/// （`"db.port"`），报错时路径自动接上前缀，和 `get_*` 一个口径。
///
/// ```mbt nocheck
/// test {
///   let get = Getter::make(
///     Value::table({
///       "port": Value::int(5432L),
///       "name": Value::str("db"),
///       "tags": Value::array([Value::str("a"), Value::str("b")]),
///     }),
///     KeyPath::root(),
///   )
///   assert_eq(get.int("port"), 5432L)
///   assert_eq(get.string("name"), "db")
///   assert_eq(get.strings("tags"), ["a", "b"])
/// }
/// ```
pub struct Getter {
  priv value : Value
  priv prefix : KeyPath
}

///|
fn Getter::make(value : Value, prefix : KeyPath) -> Getter {
  { value, prefix, }
}

///|
/// 标签的完整点分路径，报错用。
fn Getter::full(self : Getter, tag : String) -> String {
  join_paths(self.prefix, tag)
}

///|
/// 按标签取子树：路径错误接上完整前缀，形状检查留给各 getter。
fn Getter::fetch(self : Getter, tag : String) -> Value raise ConfigError {
  self.value.get_at(KeyPath::parse(tag)) catch {
    error => raise add_prefix(self.prefix, error)
  }
}

///|
/// 按标签取子树：缺失时返回 `None`，其他错误原样抛出。
fn Getter::fetch_opt(self : Getter, tag : String) -> Value? raise ConfigError {
  Some(self.fetch(tag)) catch {
    error =>
      match error {
        ConfigError::MissingKey(_) => None
        other => raise other
      }
  }
}

///|
/// 缺失就用默认值；键存在但解码失败（类型不符、越界）原样报错。
fn[T] or_missing(
  tag : String,
  default : T,
  dec : (String) -> T raise ConfigError,
) -> T raise ConfigError {
  dec(tag) catch {
    error =>
      match error {
        ConfigError::MissingKey(_) => default
        other => raise other
      }
  }
}

///|
/// 进入标签处的子树：取值 + 前缀接上标签，给嵌套结构体用。
fn Getter::enter(self : Getter, tag : String) -> Getter raise ConfigError {
  let value = self.fetch(tag)
  { value, prefix: append_path(self.prefix, KeyPath::parse(tag)), }
}

///|
/// 按标签取原始 `Value`：类型由调用方自己 match，路径错误已带前缀。
pub fn Getter::value(self : Getter, tag : String) -> Value raise ConfigError {
  self.fetch(tag)
}

///|
/// 按标签取可选原始 `Value`：缺失或 `null` 都是 `None`。
pub fn Getter::opt_value(
  self : Getter,
  tag : String,
) -> Value? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        _ => Some(value)
      }
  }
}

///|
/// 标签的完整路径（`KeyPath`）：给 json_format 的组合函数接错误前缀用。
pub fn Getter::field_path(self : Getter, tag : String) -> KeyPath {
  append_path(self.prefix, KeyPath::parse(tag))
}

///|
/// 按标签取字符串：只收 `Str` 来源，口径同 `get_string`。
pub fn Getter::string(self : Getter, tag : String) -> String raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Str(s) => s
    k => raise ConfigError::TypeMismatch(self.full(tag), "Str", k.name())
  }
}

///|
/// 按标签取布尔：只收 `Bool` 来源，口径同 `get_bool`。
pub fn Getter::bool(self : Getter, tag : String) -> Bool raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Bool(b) => b
    k => raise ConfigError::TypeMismatch(self.full(tag), "Bool", k.name())
  }
}

///|
/// 按标签取整数（`Int64`，精确不丢）：只收 `Int` 来源，口径同 `get_int`。
///
/// 浮点、字符串来源都不收——这条路径没有探针兜底，类型不对当场报。
pub fn Getter::int(self : Getter, tag : String) -> Int64 raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Int(i) => i
    k => raise ConfigError::TypeMismatch(self.full(tag), "Int", k.name())
  }
}

///|
/// 按标签取 32 位整数：越界报 `ParseError`，不静默截断。
pub fn Getter::int32(self : Getter, tag : String) -> Int32 raise ConfigError {
  let i = self.int(tag)
  if i > 2147483647L || i < -2147483648L {
    raise ConfigError::ParseError(
      "key '\{self.full(tag)}' is out of range for Int32",
    )
  }
  i.to_int()
}

///|
/// 按标签取无符号 64 位整数：只收非负 `Int` 来源，越界报 `ParseError`。
pub fn Getter::uint64(self : Getter, tag : String) -> UInt64 raise ConfigError {
  let i = self.int(tag)
  if i < 0 {
    raise ConfigError::ParseError(
      "key '\{self.full(tag)}' is out of range for UInt64",
    )
  }
  i.reinterpret_as_uint64()
}

///|
/// 按标签取浮点数：整数来源按浮点加宽，口径同 `get_float`。
pub fn Getter::float(self : Getter, tag : String) -> Double raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Float(f) => f
    ValueKind::Int(i) => i.to_double()
    k => raise ConfigError::TypeMismatch(self.full(tag), "Float", k.name())
  }
}

///|
/// 按标签取浮点数，只接受 `Float`，不把整数加宽：口径同 `get_float_strict`。
pub fn Getter::float_strict(
  self : Getter,
  tag : String,
) -> Double raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Float(f) => f
    k => raise ConfigError::TypeMismatch(self.full(tag), "Float", k.name())
  }
}

///|
/// 按标签取字节串：只收 `Bytes` 来源（CBOR 字节串），字符串来源不收。
pub fn Getter::bytes(self : Getter, tag : String) -> Bytes raise ConfigError {
  match self.fetch(tag).kind {
    ValueKind::Bytes(b) => b
    k => raise ConfigError::TypeMismatch(self.full(tag), "Bytes", k.name())
  }
}

///|
/// 数组读取的公共骨架：形状检查 + 逐元素解码，元素路径带下标（`"tags.0"`）。
fn[T] Getter::list(
  self : Getter,
  tag : String,
  dec : (Value, String) -> T raise ConfigError,
) -> Array[T] raise ConfigError {
  let items = match self.fetch(tag).kind {
    ValueKind::Array(items) => items
    k => raise ConfigError::TypeMismatch(self.full(tag), "Array", k.name())
  }
  let out : Array[T] = []
  for i, item in items {
    out.push(dec(item, "\{self.full(tag)}.\{i}"))
  }
  out
}

///|
/// 按标签取字符串数组。
pub fn Getter::strings(
  self : Getter,
  tag : String,
) -> Array[String] raise ConfigError {
  self.list(tag, (value, path) => {
    match value.kind {
      ValueKind::Str(s) => s
      k => raise ConfigError::TypeMismatch(path, "Str", k.name())
    }
  })
}

///|
/// 按标签取整数数组（`Int64`）。
pub fn Getter::ints(
  self : Getter,
  tag : String,
) -> Array[Int64] raise ConfigError {
  self.list(tag, (value, path) => {
    match value.kind {
      ValueKind::Int(i) => i
      k => raise ConfigError::TypeMismatch(path, "Int", k.name())
    }
  })
}

///|
/// 按标签取浮点数数组：整数元素按浮点加宽。
pub fn Getter::floats(
  self : Getter,
  tag : String,
) -> Array[Double] raise ConfigError {
  self.list(tag, (value, path) => {
    match value.kind {
      ValueKind::Float(f) => f
      ValueKind::Int(i) => i.to_double()
      k => raise ConfigError::TypeMismatch(path, "Float", k.name())
    }
  })
}

///|
/// 按标签取布尔数组。
pub fn Getter::bools(
  self : Getter,
  tag : String,
) -> Array[Bool] raise ConfigError {
  self.list(tag, (value, path) => {
    match value.kind {
      ValueKind::Bool(b) => b
      k => raise ConfigError::TypeMismatch(path, "Bool", k.name())
    }
  })
}

///|
/// 按标签取嵌套结构体：子 `Getter` 的前缀接上标签，错误路径随之加深。
pub fn[T : FromConfig] Getter::nested(
  self : Getter,
  tag : String,
) -> T raise ConfigError {
  T::from_config(self.enter(tag))
}

///|
/// 按标签取结构体数组：每个元素递归走 `from_config`。
pub fn[T : FromConfig] Getter::structs(
  self : Getter,
  tag : String,
) -> Array[T] raise ConfigError {
  let items = match self.fetch(tag).kind {
    ValueKind::Array(items) => items
    k => raise ConfigError::TypeMismatch(self.full(tag), "Array", k.name())
  }
  let base = append_path(self.prefix, KeyPath::parse(tag))
  let out : Array[T] = []
  for i, item in items {
    out.push(T::from_config(Getter::make(item, base.add(i.to_string()))))
  }
  out
}

///|
/// 按标签取字符串，缺失用默认值；键存在但类型不符仍然报错，绝不静默落默认。
pub fn Getter::string_or(
  self : Getter,
  tag : String,
  default : String,
) -> String raise ConfigError {
  or_missing(tag, default, t => self.string(t))
}

///|
/// 按标签取布尔，缺失用默认值；键存在但类型不符仍然报错。
pub fn Getter::bool_or(
  self : Getter,
  tag : String,
  default : Bool,
) -> Bool raise ConfigError {
  or_missing(tag, default, t => self.bool(t))
}

///|
/// 按标签取整数（`Int64`），缺失用默认值；键存在但类型不符仍然报错。
pub fn Getter::int_or(
  self : Getter,
  tag : String,
  default : Int64,
) -> Int64 raise ConfigError {
  or_missing(tag, default, t => self.int(t))
}

///|
/// 按标签取 32 位整数，缺失用默认值；键存在但越界仍然报错。
pub fn Getter::int32_or(
  self : Getter,
  tag : String,
  default : Int32,
) -> Int32 raise ConfigError {
  or_missing(tag, default, t => self.int32(t))
}

///|
/// 按标签取无符号 64 位整数，缺失用默认值；键存在但越界仍然报错。
pub fn Getter::uint64_or(
  self : Getter,
  tag : String,
  default : UInt64,
) -> UInt64 raise ConfigError {
  or_missing(tag, default, t => self.uint64(t))
}

///|
/// 按标签取浮点数，缺失用默认值；键存在但类型不符仍然报错。
pub fn Getter::float_or(
  self : Getter,
  tag : String,
  default : Double,
) -> Double raise ConfigError {
  or_missing(tag, default, t => self.float(t))
}

///|
/// 按标签取字节串，缺失用默认值；键存在但类型不符仍然报错。
pub fn Getter::bytes_or(
  self : Getter,
  tag : String,
  default : Bytes,
) -> Bytes raise ConfigError {
  or_missing(tag, default, t => self.bytes(t))
}

///|
/// 按标签取可选字符串：缺失或 `null` 都是 `None`。
pub fn Getter::opt_string(
  self : Getter,
  tag : String,
) -> String? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        ValueKind::Str(s) => Some(s)
        k => raise ConfigError::TypeMismatch(self.full(tag), "Str", k.name())
      }
  }
}

///|
/// 按标签取可选布尔：缺失或 `null` 都是 `None`。
pub fn Getter::opt_bool(self : Getter, tag : String) -> Bool? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        ValueKind::Bool(b) => Some(b)
        k => raise ConfigError::TypeMismatch(self.full(tag), "Bool", k.name())
      }
  }
}

///|
/// 按标签取可选整数（`Int64`）：缺失或 `null` 都是 `None`。
pub fn Getter::opt_int(self : Getter, tag : String) -> Int64? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        ValueKind::Int(i) => Some(i)
        k => raise ConfigError::TypeMismatch(self.full(tag), "Int", k.name())
      }
  }
}

///|
/// 按标签取可选 32 位整数：缺失或 `null` 都是 `None`，越界仍然报错。
pub fn Getter::opt_int32(
  self : Getter,
  tag : String,
) -> Int32? raise ConfigError {
  match self.opt_int(tag) {
    None => None
    Some(i) =>
      if i > 2147483647L || i < -2147483648L {
        raise ConfigError::ParseError(
          "key '\{self.full(tag)}' is out of range for Int32",
        )
      } else {
        Some(i.to_int())
      }
  }
}

///|
/// 按标签取可选无符号 64 位整数：缺失或 `null` 都是 `None`，负数仍然报错。
pub fn Getter::opt_uint64(
  self : Getter,
  tag : String,
) -> UInt64? raise ConfigError {
  match self.opt_int(tag) {
    None => None
    Some(i) =>
      if i < 0 {
        raise ConfigError::ParseError(
          "key '\{self.full(tag)}' is out of range for UInt64",
        )
      } else {
        Some(i.reinterpret_as_uint64())
      }
  }
}

///|
/// 按标签取可选浮点数：缺失或 `null` 都是 `None`，整数来源按浮点加宽。
pub fn Getter::opt_float(
  self : Getter,
  tag : String,
) -> Double? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        ValueKind::Float(f) => Some(f)
        ValueKind::Int(i) => Some(i.to_double())
        k => raise ConfigError::TypeMismatch(self.full(tag), "Float", k.name())
      }
  }
}

///|
/// 按标签取可选字节串：缺失或 `null` 都是 `None`。
pub fn Getter::opt_bytes(
  self : Getter,
  tag : String,
) -> Bytes? raise ConfigError {
  match self.fetch_opt(tag) {
    None => None
    Some(value) =>
      match value.kind {
        ValueKind::Null => None
        ValueKind::Bytes(b) => Some(b)
        k => raise ConfigError::TypeMismatch(self.full(tag), "Bytes", k.name())
      }
  }
}

///|
/// 按键提取手写结构体：先取子树，标签相对该子树解析，错误路径带完整前缀。
pub fn[T : FromConfig] Config::get_struct(
  self : Config,
  path : String,
) -> T raise ConfigError {
  T::from_config(Getter::make(self.get_value(path), KeyPath::parse(path)))
}

///|
/// 按键提取手写结构体，再跑结构体自己的 `Validate`：口径同
/// `extract_validated_from`。
pub fn[T : FromConfig + Validate] Config::get_struct_validated(
  self : Config,
  path : String,
) -> T raise ConfigError {
  let value : T = self.get_struct(path)
  Validate::validate(value, KeyPath::parse(path))
  value
}

///|
/// 把一个 `Value` 直接提取成手写结构体：标签相对该值解析，前缀为空。
pub fn[T : FromConfig] Value::to_struct(self : Value) -> T raise ConfigError {
  T::from_config(Getter::make(self, KeyPath::root()))
}

///|
/// 前缀接上相对路径，得到新的 `KeyPath`。
fn append_path(prefix : KeyPath, rel : KeyPath) -> KeyPath {
  let mut out = prefix
  for seg in rel.segments() {
    out = out.add(seg)
  }
  out
}

///|
/// 前缀 + 相对点分路径 → 完整点分路径。
fn join_paths(prefix : KeyPath, path : String) -> String {
  let text = prefix.to_string()
  if text == "" {
    path
  } else if path == "" {
    text
  } else {
    "\{text}.\{path}"
  }
}

///|
/// 把路径错误接上前缀；不带路径的错误原样透传。
fn add_prefix(prefix : KeyPath, error : ConfigError) -> ConfigError {
  match error {
    ConfigError::MissingKey(path) =>
      ConfigError::MissingKey(join_paths(prefix, path))
    ConfigError::TypeMismatch(path, expected, actual) =>
      ConfigError::TypeMismatch(join_paths(prefix, path), expected, actual)
    other => other
  }
}
