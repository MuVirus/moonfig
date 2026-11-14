// Blackbox tests for automatic format detection.

///|
using @config {
  type Config,
  type ConfigError,
  type MemorySource,
  type StringSource,
  type Value,
}

///|
using @format_detect {type Detector}

///|
/// 一个自带后缀、也参与内容判断的假格式。
///
/// 检测逻辑不该依赖真实解析器：这里只用它区分「后缀命中」和「内容命中」，
/// 所以解码结果是一张固定的表。
struct StubFormat {}

///|
impl @config.Format for StubFormat with fn decode(_ : StubFormat, _ : Bytes) -> Value raise ConfigError {
  Value::table({ "key": Value::str("stub") })
}

///|
impl @config.Format for StubFormat with fn suffixes(_ : StubFormat) -> Array[
  String,
] {
  ["stub"]
}

///|
impl @config.Format for StubFormat with fn sniff(_ : StubFormat, bytes : Bytes) -> Bool {
  let text = @utf8.decode(bytes) catch { _ => return false }
  text.has_prefix("stub:")
}

///|
fn detector() -> Detector raise ConfigError {
  Detector::new([@json_format.JsonFormat::new(), StubFormat::{ }])
}

///|
fn config_of(value : Value) -> Config raise ConfigError {
  Config::new().add(MemorySource::new(value)).build()
}

///|
/// 后缀认识时直接走后缀，大小写不敏感，也不看内容
test "detector uses a known suffix first" {
  let value = detector().decode_path("APP.STUB", @utf8.encode("{\"a\": 1}"))
  assert_eq(config_of(value).get_string("key"), "stub")
}

///|
/// 后缀认识但内容写坏了：直接报错，不偷偷换解析器
test "detector does not fall back after a known suffix fails" {
  let error = try {
    ignore(detector().decode_path("app.json", @utf8.encode("stub: 1")))
    None
  } catch {
    e => Some(e)
  }
  assert_true(error is Some(ConfigError::ParseError(_)))
}

///|
/// 没有后缀时按内容猜
test "detector sniffs content when there is no suffix" {
  let cfg = Config::new().add(StringSource::new("stub: 1", detector())).build()
  assert_eq(cfg.get_string("key"), "stub")
}

///|
/// 后缀不认识时也按内容猜
test "detector sniffs content when the suffix is unknown" {
  let value = detector().decode_path("app.conf", @utf8.encode("stub: 1"))
  assert_eq(config_of(value).get_string("key"), "stub")
}

///|
/// 后缀和内容都不认识：报 UnknownFormat，并列出候选后缀
test "detector reports UnknownFormat with supported suffixes" {
  let detector = Detector::new([@json_format.JsonFormat::new()])
  let message = try {
    ignore(detector.decode_path("app.conf", @utf8.encode("plain text")))
    "no error"
  } catch {
    ConfigError::UnknownFormat(name, suffixes) => {
      assert_eq(name, "app.conf")
      assert_eq(suffixes, ["json"])
      "cannot detect"
    }
    e => e.to_string()
  }
  assert_eq(message, "cannot detect")
}

///|
/// 重复后缀在构造阶段报错，不让顺序决定赢家
test "detector rejects duplicate suffixes" {
  let error = try {
    ignore(
      Detector::new([
        @json_format.JsonFormat::new(),
        @json_format.JsonFormat::new(),
      ]),
    )
    None
  } catch {
    e => Some(e)
  }
  assert_true(error is Some(ConfigError::ParseError(_)))
}

///|
struct FirstFormat {}

///|
impl @config.Format for FirstFormat with fn decode(_ : FirstFormat, _ : Bytes) -> Value raise ConfigError {
  Value::table({ "winner": Value::str("first") })
}

///|
impl @config.Format for FirstFormat with fn sniff(_ : FirstFormat, _ : Bytes) -> Bool {
  true
}

///|
struct SecondFormat {}

///|
impl @config.Format for SecondFormat with fn decode(_ : SecondFormat, _ : Bytes) -> Value raise ConfigError {
  Value::table({ "winner": Value::str("second") })
}

///|
impl @config.Format for SecondFormat with fn sniff(_ : SecondFormat, _ : Bytes) -> Bool {
  true
}

///|
/// 候选顺序就是优先级
test "detector candidate order is the priority" {
  let first = Detector::new([FirstFormat::{ }, SecondFormat::{ }]).decode_path(
    "app",
    @utf8.encode("anything"),
  )
  let second = Detector::new([SecondFormat::{ }, FirstFormat::{ }]).decode_path(
    "app",
    @utf8.encode("anything"),
  )
  assert_eq(config_of(first).get_string("winner"), "first")
  assert_eq(config_of(second).get_string("winner"), "second")
}
