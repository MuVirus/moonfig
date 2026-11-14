// moonfig `Value` 的 serde 后端：让任何实现 `@serde.Deserialize` 的类型
// 直接从配置里提取。
//
// serde 是 moonbit-community 的序列化框架：类型描述自己在固定数据模型上的
// 形状，格式负责读写这个模型。moonfig 的 `Value` 树在这里被包装成它的
// `Deserializer`——类型不感知配置来源，moonfig 不感知类型形状，两条路
// 各自独立。
//
// 语义与 serde 自带的 `ValueDeserializer` 对齐，同样严格：整数只收 `Int`
// 节点（范围检查，不截断浮点、不解析字符串），`deserialize_double` 把整数
// 加宽（同 `get_float`），字符串来源不能变数字或字节串。错误统一走
// `DeError`（带 serde 风格路径 `$.db.port`），入口处翻译成 `ConfigError`，
// 键名接上提取前缀，和 `get_*` 一个口径。

///|
/// moonfig `Value` 的 serde `Deserializer` 后端。
priv struct ConfigDeserializer {
  mut value : @config.Value
  mut path : @serde.Path
  mut cursor : Int32
}

///|
fn ConfigDeserializer::make(
  value : @config.Value,
  path : @serde.Path,
) -> ConfigDeserializer {
  { value, path, cursor: 0, }
}

///|
fn ConfigDeserializer::child(
  self : ConfigDeserializer,
  value : @config.Value,
  path : @serde.Path,
) -> ConfigDeserializer {
  ignore(self)
  { value, path, cursor: 0, }
}

///|
/// 当前节点的形状名，报错里的 "actual" 用 moonfig 的口径。
fn ConfigDeserializer::kind_name(self : ConfigDeserializer) -> String {
  ignore(self)
  self.value.kind.name()
}

///|
fn[T] ConfigDeserializer::mismatch(
  self : ConfigDeserializer,
  expected : String,
) -> T raise @serde.DeError {
  raise @serde.DeError::InvalidType(
    path=self.path,
    expected~,
    found=self.kind_name(),
  )
}

///|
/// 整数来源：只收 `Int` 节点，精确 `Int64`。浮点、字符串来源都不收。
fn ConfigDeserializer::int_source(
  self : ConfigDeserializer,
) -> Int64 raise @serde.DeError {
  match self.value.kind {
    @config.ValueKind::Int(i) => i
    _ => self.mismatch("Int")
  }
}

///|
/// 范围检查：越界报 `InvalidValue`，名字沿用 moonfig 的口径。
fn ConfigDeserializer::int_in_range(
  self : ConfigDeserializer,
  lo : Int64,
  hi : Int64,
  expected : String,
) -> Int64 raise @serde.DeError {
  let i = self.int_source()
  if i < lo || i > hi {
    raise @serde.DeError::InvalidValue(
      path=self.path,
      expected~,
      found=i.to_string(),
    )
  }
  i
}

///|
/// Table 快照成 (键, 值) 对；键包装成 `Str` 节点，map 协议的键要走
/// `K::deserialize`。非 Table 报 `InvalidType`。
fn ConfigDeserializer::table_entries(
  self : ConfigDeserializer,
) -> Array[(@config.Value, @config.Value)] raise @serde.DeError {
  match self.value.kind {
    @config.ValueKind::Table(t) => {
      let out : Array[(@config.Value, @config.Value)] = []
      for k, v in t {
        out.push((@config.Value::str(k), v))
      }
      out
    }
    _ => self.mismatch("Table")
  }
}

///|
fn ConfigDeserializer::seq_items(
  self : ConfigDeserializer,
) -> Array[@config.Value] raise @serde.DeError {
  match self.value.kind {
    @config.ValueKind::Array(items) => items
    _ => self.mismatch("Array")
  }
}

///|
fn variant_index(
  variants : ArrayView[String],
  name : String,
  path : @serde.Path,
) -> Int32 raise @serde.DeError {
  for i, candidate in variants {
    if candidate == name {
      return i
    }
  }
  raise @serde.DeError::UnknownVariant(path~, variant=name, expected=variants)
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn path(self) {
  self.path
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_unit(self) raise {
  guard self.value.kind is @config.ValueKind::Null else {
    self.mismatch("Null")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_bool(self) raise {
  match self.value.kind {
    @config.ValueKind::Bool(b) => b
    _ => self.mismatch("Bool")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_byte(self) raise {
  self.int_in_range(0L, 255L, "Byte").to_byte()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_int16(self) raise {
  Int16::from_int64(self.int_in_range(-32768L, 32767L, "Int16"))
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_uint16(self) raise {
  self.int_in_range(0L, 65535L, "UInt16").to_uint16()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_int(self) raise {
  self.int_in_range(-2147483648L, 2147483647L, "Int").to_int()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_uint(self) raise {
  self.int_in_range(0L, 4294967295L, "UInt").reinterpret_as_uint64().to_uint()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_int64(self) raise {
  self.int_source()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_uint64(self) raise {
  let i = self.int_source()
  if i < 0 {
    raise @serde.DeError::InvalidValue(
      path=self.path,
      expected="UInt64",
      found=i.to_string(),
    )
  }
  i.reinterpret_as_uint64()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_float(self) raise {
  @float.Float::from_double(self.as_double())
}

///|
/// 浮点读取：`Float` 原样，`Int` 加宽，口径同 `get_float`。
fn ConfigDeserializer::as_double(
  self : ConfigDeserializer,
) -> Double raise @serde.DeError {
  match self.value.kind {
    @config.ValueKind::Float(f) => f
    @config.ValueKind::Int(i) => i.to_double()
    _ => self.mismatch("Float")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_double(self) raise {
  self.as_double()
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_char(self) raise {
  match self.value.kind {
    @config.ValueKind::Str(s) => {
      let mut first : Char? = None
      let mut count = 0
      for c in s {
        if count == 0 {
          first = Some(c)
        }
        count = count + 1
      }
      match first {
        Some(c) if count == 1 => c
        _ =>
          raise @serde.DeError::InvalidValue(
            path=self.path,
            expected="Char",
            found=s,
          )
      }
    }
    _ => self.mismatch("Char")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_string(self) raise {
  match self.value.kind {
    @config.ValueKind::Str(s) => s
    _ => self.mismatch("Str")
  }
}

///|
/// 字节串只收 `Bytes` 节点：字符串来源不能变成字节串，和探针一个口径。
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_bytes(self) raise {
  match self.value.kind {
    @config.ValueKind::Bytes(b) => b
    _ => self.mismatch("Bytes")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_option(self) raise {
  if self.value.kind is @config.ValueKind::Null {
    None
  } else {
    Some(@serde.Deserialize::deserialize(self))
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_seq_begin(
  self,
) raise {
  let items = self.seq_items()
  self.cursor = 0
  Some(items.length())
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_seq_next(
  self,
) raise {
  let items = self.seq_items()
  if self.cursor >= items.length() {
    return None
  }
  let i = self.cursor
  self.cursor = i + 1
  Some(
    @serde.Deserialize::deserialize(self.child(items[i], self.path.index(i))),
  )
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_map_begin(
  self,
) raise {
  let entries = self.table_entries()
  self.cursor = 0
  Some(entries.length())
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_map_next_key(
  self,
) raise {
  let entries = self.table_entries()
  if self.cursor >= entries.length() {
    return None
  }
  let entry = entries[self.cursor]
  @serde.Deserialize::deserialize(self.child(entry.0, self.path))
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_map_value(
  self,
) raise {
  let entries = self.table_entries()
  if self.cursor >= entries.length() {
    raise @serde.DeError::Eof(path=self.path)
  }
  let entry = entries[self.cursor]
  self.cursor = self.cursor + 1
  let name = match entry.0.kind {
    @config.ValueKind::Str(s) => s
    other => other.name()
  }
  @serde.Deserialize::deserialize(self.child(entry.1, self.path.key(name)))
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_struct_begin(
  self,
  _name,
  _fields,
) raise {
  let _ = self.table_entries()
  self.cursor = 0
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_field_name(
  self,
) raise {
  let entries = self.table_entries()
  if self.cursor >= entries.length() {
    return None
  }
  match entries[self.cursor].0.kind {
    @config.ValueKind::Str(s) => Some(s)
    _ => None
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_field_value(
  self,
) raise {
  let entries = self.table_entries()
  if self.cursor >= entries.length() {
    raise @serde.DeError::Eof(path=self.path)
  }
  let entry = entries[self.cursor]
  self.cursor = self.cursor + 1
  let name = match entry.0.kind {
    @config.ValueKind::Str(s) => s
    other => other.name()
  }
  @serde.Deserialize::deserialize(self.child(entry.1, self.path.key(name)))
}

///|
/// 丢弃当前字段的值：Table 在内存里，跳过就是不往下走。
impl @serde.Deserializer for ConfigDeserializer with fn skip_value(self) {
  self.cursor = self.cursor + 1
}

///|
/// 元组按序列协议读：值已在内存里，这就是元组的正确读法（serde 自带的
/// `Value` 后端同款）。
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_tuple_begin(
  self,
  _len,
) {
  let _ = @serde.Deserializer::deserialize_seq_begin(self)
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_tuple_next(
  self,
) {
  match @serde.Deserializer::deserialize_seq_next(self) {
    Some(v) => v
    None => raise @serde.DeError::Eof(path=self.path)
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_tuple_end(
  self,
) {
  ignore(self)
}

///|
/// 枚举：`Str` 是 unit 变体，单条目 Table 是外部标签变体（`{变体名: 载荷}`）。
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_enum_begin(
  self,
  _name,
  variants,
) raise {
  match self.value.kind {
    @config.ValueKind::Str(variant) => {
      let index = variant_index(variants, variant, self.path)
      self.value = @config.Value::null()
      index
    }
    @config.ValueKind::Table(_) => {
      let entries = self.table_entries()
      match entries {
        [(key, payload)] =>
          match key.kind {
            @config.ValueKind::Str(variant) => {
              let index = variant_index(variants, variant, self.path)
              self.path = self.path.key(variant)
              self.value = payload
              self.cursor = 0
              index
            }
            _ => self.mismatch("Str")
          }
        _ => self.mismatch("Map")
      }
    }
    _ => self.mismatch("Str")
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_unit_variant(
  self,
) {
  ignore(self)
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_newtype_variant(
  self,
) raise {
  @serde.Deserialize::deserialize(self)
}

///|
/// 把当前节点转成 serde 的数据模型，供 `deserialize_any` 与未标签枚举用。
/// `Str` 按 serde 的约定持 UTF-8 字节视图。
fn to_data_model(value : @config.Value) -> @serde.Value {
  match value.kind {
    @config.ValueKind::Null => @serde.Value::Null
    @config.ValueKind::Bool(b) => @serde.Value::Boolean(b)
    @config.ValueKind::Int(i) => @serde.Value::Int(i)
    @config.ValueKind::Float(f) => @serde.Value::Double(f)
    @config.ValueKind::Str(s) => @serde.Value::Str(@utf8.encode(s)[:])
    @config.ValueKind::Bytes(b) => @serde.Value::Bytes(b)
    @config.ValueKind::Array(arr) =>
      @serde.Value::Seq(ReadOnlyArray::from_array(arr.map(to_data_model)))
    @config.ValueKind::Table(t) => {
      let out : Array[(@serde.Value, @serde.Value)] = []
      for k, v in t {
        out.push((@serde.Value::Str(@utf8.encode(k)[:]), to_data_model(v)))
      }
      @serde.Value::Map(ReadOnlyArray::from_array(out))
    }
  }
}

///|
impl @serde.Deserializer for ConfigDeserializer with fn deserialize_any(self) raise {
  to_data_model(self.value)
}

///|
/// serde `Path` 转点分键名（不含前缀；`Root` 为空串）。
fn serde_path_text(path : @serde.Path) -> String {
  match path {
    @serde.Path::Root => ""
    @serde.Path::Key(parent, name) => join_text(serde_path_text(parent), name)
    @serde.Path::Index(parent, i) =>
      join_text(serde_path_text(parent), i.to_string())
  }
}

///|
fn join_text(a : String, b : String) -> String {
  if a == "" {
    b
  } else if b == "" {
    a
  } else {
    "\{a}.\{b}"
  }
}

///|
/// `DeError` → `ConfigError`：键名接上提取前缀，口径与 `get_*` 一致。
fn to_config_error(
  prefix : @config.KeyPath,
  error : @serde.DeError,
) -> @config.ConfigError {
  let key = join_text(prefix.to_string(), serde_path_text(error.path()))
  match error {
    @serde.DeError::InvalidType(expected~, found~, ..) =>
      @config.ConfigError::TypeMismatch(key, expected, found)
    @serde.DeError::InvalidValue(expected~, found~, ..) =>
      @config.ConfigError::InvalidValue(key, expected, found)
    @serde.DeError::MissingField(field~, ..) =>
      @config.ConfigError::MissingKey(join_text(key, field))
    @serde.DeError::UnknownField(field~, ..) =>
      @config.ConfigError::ParseError(
        "key '\{key}' has unknown field `\{field}`",
      )
    @serde.DeError::UnknownVariant(variant~, ..) =>
      @config.ConfigError::ParseError(
        "key '\{key}' has unknown variant `\{variant}`",
      )
    @serde.DeError::Eof(..) =>
      @config.ConfigError::ParseError("key '\{key}': unexpected end of value")
    @serde.DeError::InvalidLength(..) =>
      @config.ConfigError::ParseError("key '\{key}': invalid length")
    @serde.DeError::DeCustom(message~, ..) =>
      @config.ConfigError::ParseError("key '\{key}': \{message}")
  }
}

///|
fn[T : @serde.Deserialize] serde_extract_at(
  value : @config.Value,
  prefix : @config.KeyPath,
) -> T raise @config.ConfigError {
  let deserializer = ConfigDeserializer::make(value, @serde.Path::Root)
  @serde.Deserialize::deserialize(deserializer) catch {
    error => raise to_config_error(prefix, error)
  }
}

///|
/// 把整个 `Value` 提取成实现 `@serde.Deserialize` 的类型：严格类型，
/// 错误口径与 `get_*` 一致。
///
/// 提取走 serde 的数据模型协议，类型只描述自己的形状，不感知配置来源；
/// 整数只收 `Int` 节点，浮点加宽整数，字符串来源不能变成数字或字节串。
pub fn[T : @serde.Deserialize] extract_serde(
  v : @config.Value,
) -> T raise @config.ConfigError {
  serde_extract_at(v, @config.KeyPath::root())
}

///|
/// 按键取子树再提取：错误键名带完整前缀。
pub fn[T : @serde.Deserialize] extract_serde_from(
  cfg : @config.Config,
  path : String,
) -> T raise @config.ConfigError {
  serde_extract_at(cfg.get_value(path), @config.KeyPath::parse(path))
}

///|
/// `FromConfig` 的组合点：把标签处的子树交给 serde 提取，两条路径在
/// 字段级混搭——手写字段用 `Getter`，serde 字段一行委托。
pub fn[T : @serde.Deserialize] serde_field(
  get : @config.Getter,
  tag : String,
) -> T raise @config.ConfigError {
  serde_extract_at(get.value(tag), get.field_path(tag))
}
