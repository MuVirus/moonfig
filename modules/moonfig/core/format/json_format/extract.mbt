// 提取到结构体：`Value` → `Json` → `FromJson`。
//
// 整数的映射和错误消息都在这里收口：
// - 整数映射成 `Json::Number`，大整数靠 `repr` 保住原文（见 `to_json`）
// - `derive(FromJson)` 的报错反查回 `Value`，统一成 `ConfigError`

///|
/// 结构体里的 64 位整数字段。
///
/// core 的 `FromJson for Int64` 只接受 JSON 字符串，而本库把整数映射成
/// JSON 数字，所以结构体里不能直接写 `port : Int64`。改成
/// `port : Int64Text`，它直接读 `Json::Number` 的 `repr`，大整数不丢：
///
/// ```mbt check
/// test {
///   let json = @json_format.to_json(@config.Value::int(9007199254740993L))
///   let id : @json_format.Int64Text = @json.from_json(json)
///   assert_eq(id.to_int64(), 9007199254740993L)
/// }
/// ```
///
/// 全精度的另一条路是按键取值：`get_int` 直接返回 `Int64`。
#derive(Eq)
pub struct Int64Text {
  value : Int64
}

///|
pub extend Int64Text with Eq::{equal, not_equal}

///|
pub fn Int64Text::new(value : Int64) -> Int64Text {
  { value, }
}

///|
pub fn Int64Text::to_int64(self : Int64Text) -> Int64 {
  self.value
}

///|
/// 只认 `Value::int` 映射出来的数字：它一定带 `repr`。
/// 字符串、浮点都不收，否则就成了隐式转换。
pub impl @json.FromJson for Int64Text with fn from_json(json, path) {
  let text = match json {
    Json::Number(_, repr~) =>
      match repr {
        Some(text) => text
        None =>
          raise @json.JsonDecodeError(
            (path, "Int64::from_json: expected integer"),
          )
      }
    _ =>
      raise @json.JsonDecodeError((path, "Int64::from_json: expected integer"))
  }
  if !is_integer_literal(text) {
    raise @json.JsonDecodeError((path, "Int64::from_json: expected integer"))
  }
  {
    value: int64_of(text) catch {
      @config.ConfigError::ParseError(message) =>
        raise @json.JsonDecodeError((path, message))
      error => raise @json.JsonDecodeError((path, error.to_string()))
    },
  }
}

///|
pub extend Int64Text with @json.FromJson::{from_json}

///|
pub impl @json.ToJson for Int64Text with fn to_json(self) {
  Json::number(self.value.to_double(), repr=self.value.to_string())
}

///|
pub extend Int64Text with @json.ToJson::{to_json}

///|
/// 结构体里的无符号 64 位整数字段，用法同 `Int64Text`。
#derive(Eq)
pub struct UInt64Text {
  value : UInt64
}

///|
pub extend UInt64Text with Eq::{equal, not_equal}

///|
pub fn UInt64Text::new(value : UInt64) -> UInt64Text {
  { value, }
}

///|
pub fn UInt64Text::to_uint64(self : UInt64Text) -> UInt64 {
  self.value
}

///|
pub impl @json.FromJson for UInt64Text with fn from_json(json, path) {
  let text = match json {
    Json::Number(_, repr~) =>
      match repr {
        Some(text) => text
        None =>
          raise @json.JsonDecodeError(
            (path, "UInt64::from_json: expected integer"),
          )
      }
    _ =>
      raise @json.JsonDecodeError((path, "UInt64::from_json: expected integer"))
  }
  if !is_integer_literal(text) || text.contains("-") {
    raise @json.JsonDecodeError(
      (path, "UInt64::from_json: expected non-negative integer"),
    )
  }
  let big = @bigint.BigInt::from_string(text)
  if big.compare_uint64(18446744073709551615UL) > 0 {
    raise @json.JsonDecodeError((path, "UInt64::from_json: overflow"))
  }
  { value: big.to_uint64(), }
}

///|
pub extend UInt64Text with @json.FromJson::{from_json}

///|
pub impl @json.ToJson for UInt64Text with fn to_json(self) {
  Json::number(self.value.to_double(), repr=self.value.to_string())
}

///|
pub extend UInt64Text with @json.ToJson::{to_json}

///|
/// 提取到结构体：`Value` → `Json` → `FromJson`。
///
/// 用户的类型用编译器自带的 `derive(FromJson)`。
///
/// 实验性：这条路径的入口和严格性探针可能随版本变化；默认走 `FromConfig`，
/// 见 `docs/design/from_config.md`。
#alert(experimental, "derive(FromJson) extraction is experimental and may change; prefer FromConfig")
pub fn[T : @json.FromJson] extract(
  v : @config.Value,
) -> T raise @config.ConfigError {
  extract_at(v, "")
}

///|
/// 取配置里某个路径的值并提取成用户结构体。
///
/// 原来是 `Config::extract`，拆分时降级成自由函数——理由同 `to_json`。
///
/// 实验性：同 `extract`。
#alert(experimental, "derive(FromJson) extraction is experimental and may change; prefer FromConfig")
pub fn[T : @json.FromJson] extract_from(
  cfg : @config.Config,
  path : String,
) -> T raise @config.ConfigError {
  extract_at(cfg.get_value(path), path)
}

///|
/// 取配置里某个路径的值，提取成结构体，再跑结构体自己的 `Validate`。
///
/// 未知键不在这条路上：`derive(FromJson)` 会忽略结构体里没有的字段，
/// 要查未知键请用 `Rule::allowed_keys` 按键校验。
///
/// 实验性：同 `extract`。
#alert(experimental, "derive(FromJson) extraction is experimental and may change; prefer FromConfig")
pub fn[T : @json.FromJson + @config.Validate] extract_validated_from(
  cfg : @config.Config,
  path : String,
) -> T raise @config.ConfigError {
  let value : T = extract_from(cfg, path)
  @config.Validate::validate(value, @config.KeyPath::parse(path))
  value
}

///|
/// 提取失败时把 core 的错误翻成库自己的错误：
/// 键名、期望类型、实际类型，和 `get_*` 一个口径。
fn[T : @json.FromJson] extract_at(
  v : @config.Value,
  prefix : String,
) -> T raise @config.ConfigError {
  let decoded : T = @json.from_json(to_json(v)) catch {
    @json.JsonDecodeError((path, message)) =>
      raise explain(v, prefix, path, message)
  }
  // 正常解码可能把特殊形状的来源静默换成了别的类型。下面三个探针都逐个
  // 节点检查：一次解码只替换一个节点，其余节点与正常解码完全相同，所以
  // 报错必然来自被替换的节点——某个节点的失败不会掩盖后面的节点。（早期
  // 版本整棵树换一遍只解一次，解码停在第一个错误上，`BigInt` / `Char`
  // 这类字段的失败会吞掉探针，让后面字段的违规静默通过。）
  //
  // 标准库的 `Int::from_json` 对 `Json::Number` 只做范围检查，小数会被
  // `to_int()` 直接截断。浮点探针把 `Float` 节点换成字符串 `"NaN"`：
  // `Double` / `Float` 接受它，整数类型只接受数字，会报错。
  let float_paths : Array[@config.KeyPath] = []
  collect_float_paths(v, @config.KeyPath::root(), float_paths)
  for target in float_paths {
    let probe : T? = Some(
      @json.from_json(to_float_probe_json(v, @config.KeyPath::root(), target)),
    ) catch {
      @json.JsonDecodeError((path, message)) => {
        let expected = expected_name(message)
        if is_integer_name(expected) {
          raise explain(v, prefix, path, message)
        }
        // 目标节点的字段不接受 "NaN" 但也不是整数字段：可能是不接受
        // "NaN" 的自定义类型，保持标准库原本的提取结果。
        None
      }
    }
    ignore(probe)
  }
  // 标准库有些类型会把字符串当成别的形状：`Double` / `Float` 接受
  // `"NaN"` / `"Infinity"` / `"-Infinity"`，`Int64` / `UInt64` / `BigInt`
  // 直接解析数字字符串。正常解码能过，但那是字符串来源变成了数字，和
  // 严格类型不符。字符串探针把 `Str` 节点逐个换成普通标记串再解一次：
  // 这些类型会拒绝，字符串字段照常接受。
  let str_paths : Array[@config.KeyPath] = []
  collect_str_paths(v, @config.KeyPath::root(), str_paths)
  for target in str_paths {
    let probe : T? = Some(
      @json.from_json(to_str_probe_json(v, @config.KeyPath::root(), target)),
    ) catch {
      @json.JsonDecodeError((path, message)) => {
        let expected = expected_name(message)
        match expected {
          "Float" | "Bytes" | "Int64" | "UInt64" | "BigInt" =>
            raise explain(v, prefix, path, message)
          _ => None
        }
      }
    }
    ignore(probe)
  }
  // `Bytes` 映射成 `Json::String`（可打印 ASCII 直通，其余 `\xHH`），正常
  // 解码分不出字节来源和字符串来源。这里逐个把 Bytes 节点换成一个非字符串
  // 值再解一次：字节字段会报期望 Bytes（合法）；报期望 String 说明字节来源
  // 被当成字符串了；报期望 Float / Int64 / UInt64 / BigInt 说明字节内容被
  // 标准库静默解析成了数字，同样是隐式转换，拒绝。不用 `null` 是因为可选
  // 类型可能把 `null` 当成缺省值，直接放过。
  let bytes_paths : Array[@config.KeyPath] = []
  collect_bytes_paths(v, @config.KeyPath::root(), bytes_paths)
  for target in bytes_paths {
    let probe : T? = Some(
      @json.from_json(to_bytes_probe_json(v, @config.KeyPath::root(), target)),
    ) catch {
      @json.JsonDecodeError((path, message)) =>
        match expected_name(message) {
          "Str" | "Float" | "Int64" | "UInt64" | "BigInt" =>
            raise explain(v, prefix, path, message)
          _ => None
        }
    }
    ignore(probe)
  }
  decoded
}

///|
/// 树里所有 `Float` 节点的路径，浮点探针逐个检查。
fn collect_float_paths(
  v : @config.Value,
  current : @config.KeyPath,
  out : Array[@config.KeyPath],
) -> Unit {
  match v.kind {
    @config.ValueKind::Float(_) => out.push(current)
    @config.ValueKind::Array(items) =>
      for i, item in items {
        collect_float_paths(item, current.add(i.to_string()), out)
      }
    @config.ValueKind::Table(table) =>
      for key, item in table {
        collect_float_paths(item, current.add(key), out)
      }
    _ => ()
  }
}

///|
/// 树里所有 `Str` 节点的路径，字符串探针逐个检查。
fn collect_str_paths(
  v : @config.Value,
  current : @config.KeyPath,
  out : Array[@config.KeyPath],
) -> Unit {
  match v.kind {
    @config.ValueKind::Str(_) => out.push(current)
    @config.ValueKind::Array(items) =>
      for i, item in items {
        collect_str_paths(item, current.add(i.to_string()), out)
      }
    @config.ValueKind::Table(table) =>
      for key, item in table {
        collect_str_paths(item, current.add(key), out)
      }
    _ => ()
  }
}

///|
/// 只有目标路径上的 `Float` 换成字符串 `"NaN"`，其余节点保持正常映射，
/// 见 `extract_at`。目标节点以外的浮点不动，不影响其它字段的解码。
fn to_float_probe_json(
  v : @config.Value,
  current : @config.KeyPath,
  target : @config.KeyPath,
) -> Json {
  if same_key_path(current, target) {
    return Json::string("NaN")
  }
  match v.kind {
    @config.ValueKind::Array(items) => {
      let out : Array[Json] = []
      for i, item in items {
        out.push(to_float_probe_json(item, current.add(i.to_string()), target))
      }
      Json::array(out)
    }
    @config.ValueKind::Table(table) => {
      let obj = Map([], capacity=table.capacity())
      for key, item in table {
        obj[key] = to_float_probe_json(item, current.add(key), target)
      }
      Json::object(obj)
    }
    _ => to_json(v)
  }
}

///|
/// 只有目标路径上的 `Str` 换成标记串，其余节点保持正常映射，见 `extract_at`。
///
/// 标记不能是 `"NaN"` / `"Infinity"` / `"-Infinity"`，否则浮点类型会照收。
/// 标记里带换行，`Bytes::from_json` 只收可打印 ASCII 和 `\xHH`，也会拒绝它：
/// 字符串来源不能因此变成字节串。
fn to_str_probe_json(
  v : @config.Value,
  current : @config.KeyPath,
  target : @config.KeyPath,
) -> Json {
  if same_key_path(current, target) {
    return Json::string("__moonfig_string_probe__\n")
  }
  match v.kind {
    @config.ValueKind::Array(items) => {
      let out : Array[Json] = []
      for i, item in items {
        out.push(to_str_probe_json(item, current.add(i.to_string()), target))
      }
      Json::array(out)
    }
    @config.ValueKind::Table(table) => {
      let obj = Map([], capacity=table.capacity())
      for key, item in table {
        obj[key] = to_str_probe_json(item, current.add(key), target)
      }
      Json::object(obj)
    }
    _ => to_json(v)
  }
}

///|
/// 收集所有 `Bytes` 节点的路径，字节探针逐个检查。
fn collect_bytes_paths(
  v : @config.Value,
  current : @config.KeyPath,
  out : Array[@config.KeyPath],
) -> Unit {
  match v.kind {
    @config.ValueKind::Bytes(_) => out.push(current)
    @config.ValueKind::Array(items) =>
      for i, item in items {
        collect_bytes_paths(item, current.add(i.to_string()), out)
      }
    @config.ValueKind::Table(table) =>
      for key, item in table {
        collect_bytes_paths(item, current.add(key), out)
      }
    _ => ()
  }
}

///|
/// 只有目标路径上的 `Bytes` 换成一个非字符串值，其余节点保持正常映射。
fn to_bytes_probe_json(
  v : @config.Value,
  current : @config.KeyPath,
  target : @config.KeyPath,
) -> Json {
  if same_key_path(current, target) {
    return Json::boolean(true)
  }
  match v.kind {
    @config.ValueKind::Array(items) => {
      let out : Array[Json] = []
      for i, item in items {
        out.push(to_bytes_probe_json(item, current.add(i.to_string()), target))
      }
      Json::array(out)
    }
    @config.ValueKind::Table(table) => {
      let obj = Map([], capacity=table.capacity())
      for key, item in table {
        obj[key] = to_bytes_probe_json(item, current.add(key), target)
      }
      Json::object(obj)
    }
    _ => to_json(v)
  }
}

///|
fn same_key_path(a : @config.KeyPath, b : @config.KeyPath) -> Bool {
  a.segments().to_owned() == b.segments().to_owned()
}

///|
/// `FromConfig` 的组合点：把标签处的子树交给 `derive(FromJson)` 提取，
/// 严格探针照常生效，错误路径接上 `Getter` 的完整前缀。
///
/// 嵌套结构体不需要逐字段手写：子结构体继续用 derive(FromJson)，字段里
/// 一行委托，两条路径在字段级混搭。
///
/// 实验性：委托的是 `derive(FromJson)` 路径，入口和严格性探针可能随版本变化。
///
/// ```mbt nocheck
/// impl FromConfig for Server with fn from_config(get : Getter) -> Server raise ConfigError {
///   {
///     host: get.string("db-host"),
///     db: @jsonfmt.json_field(get, "db"), // DbCfg 用 derive(FromJson) 提取
///   }
/// }
/// ```
#alert(experimental, "json_field delegates to the experimental derive(FromJson) path and may change")
pub fn[T : @json.FromJson] json_field(
  g : @config.Getter,
  tag : String,
) -> T raise @config.ConfigError {
  extract_at(g.value(tag), g.field_path(tag).to_string())
}

///|
/// 探针报出来的期望类型是不是整数。只拦这类错误，避免误伤自定义浮点包装。
fn is_integer_name(name : String) -> Bool {
  match name {
    "Int" | "Int32" | "Int64" | "UInt" | "UInt32" | "UInt64" => true
    _ => false
  }
}

///|
fn explain(
  v : @config.Value,
  prefix : String,
  path : @json.JsonPath,
  message : String,
) -> @config.ConfigError {
  // JsonPath 的 Show 是 JSON Pointer（`/db/port`），直接拿来当路径用
  let segments = pointer_segments(path.to_string())
  let key = join_key(prefix, segments)
  let marker = "Missing field "
  if message.has_prefix(marker) {
    let field = message[marker.length():].to_owned()
    return @config.ConfigError::MissingKey(
      if key == "(root)" {
        field
      } else {
        "\{key}.\{field}"
      },
    )
  }
  let expected = expected_name(message)
  let actual = match value_at(v, segments) {
    Some(found) => found.kind.name()
    None => "unknown"
  }
  if message.contains("expected number in string representation") &&
    actual == "Int" {
    // 整数来源落进了 `Int64` / `UInt64` / `BigInt` 字段：换个类型就能取，
    // 不是数据的问题。探针触发的同款报错说明来源不是整数（字符串、字节
    // 串被标准库解析成了数字），按普通的类型不符报，别误导用户去换类型。
    // `BigInt` 的解析失败是 "invalid number in string representation"，
    // 本来就不进这个分支。
    return @config.ConfigError::ParseError(
      "key '\{key}' is a 64-bit integer: declare the struct field as Int64Text or use get_int",
    )
  }
  if message.contains("overflow") {
    return @config.ConfigError::ParseError(
      "key '\{key}' is out of range for \{expected}",
    )
  }
  @config.ConfigError::TypeMismatch(key, expected, actual)
}

///|
/// core 的 `Xxx::from_json: ...` → 库里的类型名
fn expected_name(message : String) -> String {
  if message.has_prefix("Expected object") {
    return "Table"
  }
  if message.has_prefix("Expected array") {
    return "Array"
  }
  let name = match message.find("::") {
    Some(index) => message[:index].to_owned()
    None => "Json"
  }
  match name {
    "String" | "View" => "Str"
    "Double" | "Float" => "Float"
    "Map" => "Table"
    "Unit" => "Null"
    _ => name
  }
}

///|
/// JSON Pointer → 路径段，按 RFC 6901 反转义
fn pointer_segments(pointer : String) -> Array[String] {
  let segments : Array[String] = []
  for part in pointer.split("/") {
    let segment = part.to_owned()
    if segment == "" {
      continue
    }
    segments.push(unescape_token(segment))
  }
  segments
}

///|
fn unescape_token(token : String) -> String {
  token.replace_all(old="~1", new="/").replace_all(old="~0", new="~")
}

///|
fn join_key(prefix : String, segments : Array[String]) -> String {
  let mut key = prefix
  for segment in segments {
    key = if key == "" { segment } else { "\{key}.\{segment}" }
  }
  if key == "" {
    "(root)"
  } else {
    key
  }
}

///|
/// 按路径段在 `Value` 上走一遍，用来报“实际类型”
fn value_at(v : @config.Value, segments : Array[String]) -> @config.Value? {
  let mut current = v
  for segment in segments {
    let next = match current.kind {
      @config.ValueKind::Table(table) => table.get(segment)
      @config.ValueKind::Array(items) =>
        match index_of(segment) {
          Some(index) if index >= 0 && index < items.length() =>
            Some(items[index])
          _ => None
        }
      _ => None
    }
    match next {
      Some(found) => current = found
      None => return None
    }
  }
  Some(current)
}

///|
fn index_of(segment : String) -> Int32? {
  if segment == "" {
    return None
  }
  let mut index = 0
  for ch in segment {
    if ch < '0' || ch > '9' {
      return None
    }
    index = index * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(index)
}
