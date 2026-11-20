// Whitebox tests for the internal helpers.

///|
/// 默认只按 `.` 拆层，下划线留在键名里
test "key_path keeps underscores flat by default" {
  assert_eq(key_path("Db_PORT.Host", "X", ""), ["db_port", "host"])
}

///|
/// 给定分隔符后按分隔符和 `.` 拆层，统一小写
test "key_path splits on the separator and lowercases" {
  assert_eq(key_path("Db_PORT.Host", "X", "_"), ["db", "port", "host"])
}

///|
/// 多字符分隔符按字面匹配，单个下划线留在键名里
test "key_path supports a multi-character separator" {
  assert_eq(key_path("DB__HOST_NAME.PORT", "X", "__"), [
    "db", "host_name", "port",
  ])
}

///|
/// 单个 `_` 当分隔符时，连续两个 `_` 是空的一层
test "key_path rejects an empty layer" {
  let message = try {
    ignore(key_path("A__B", "APP_A__B", "_"))
    "no error"
  } catch {
    @config.ConfigError::ParseError(message) => message
    e => e.to_string()
  }
  assert_true(message.contains("APP_A__B"))
}

///|
/// 两个变量落到同一个路径时点名两个，不按遍历顺序随便赢
test "assign rejects two variables on one path" {
  let root : Map[String, @config.Value] = Map([])
  let seen : Map[String, String] = Map([])
  assign(root, seen, ["db", "port"], "APP_DB_PORT", @config.Value::int(1L))
  let message = try {
    assign(root, seen, ["db", "port"], "APP_db_port", @config.Value::int(2L))
    "no error"
  } catch {
    @config.ConfigError::ParseError(message) => message
    e => e.to_string()
  }
  assert_true(message.contains("APP_DB_PORT"))
  assert_true(message.contains("APP_db_port"))
  assert_true(message.contains("db.port"))
}

///|
/// 同一个变量重复写入不算冲突（后写的赢）
test "assign accepts the same variable twice" {
  let root : Map[String, @config.Value] = Map([])
  let seen : Map[String, String] = Map([])
  assign(root, seen, ["a"], "APP_A", @config.Value::int(1L))
  assign(root, seen, ["a"], "APP_A", @config.Value::int(2L))
  assert_eq(@config.Value::table(root).get_path("a"), @config.Value::int(2L))
}
