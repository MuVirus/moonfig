// Whitebox tests: 路径拼接与错误前缀的私有边界。

///|
test "join_paths handles empty prefix and relative path" {
  assert_eq(join_paths(KeyPath::root(), "a.b"), "a.b")
  assert_eq(join_paths(KeyPath::parse("srv"), "a.b"), "srv.a.b")
  assert_eq(join_paths(KeyPath::parse("srv"), ""), "srv")
  assert_eq(join_paths(KeyPath::root(), ""), "")
}

///|
test "append_path composes segments" {
  let path = append_path(KeyPath::parse("srv"), KeyPath::parse("db.port"))
  assert_eq(path.to_string(), "srv.db.port")
  let empty = append_path(KeyPath::root(), KeyPath::root())
  assert_eq(empty.to_string(), "")
}

///|
test "add_prefix rewrites path errors only" {
  let prefixed = add_prefix(
    KeyPath::parse("srv"),
    ConfigError::MissingKey("db.host"),
  )
  assert_eq(
    prefixed.to_string(),
    "missing key 'srv.db.host': no source provides it",
  )
  let mismatch = add_prefix(
    KeyPath::parse("srv"),
    ConfigError::TypeMismatch("db.port", "Int", "Str"),
  )
  assert_eq(mismatch.to_string(), "key 'srv.db.port': expected Int, got Str")
  let passthrough = add_prefix(
    KeyPath::parse("srv"),
    ConfigError::ParseError("boom"),
  )
  assert_eq(passthrough.to_string(), "parse error: boom")
}

///|
test "fetch_opt returns None only for missing keys" {
  let get = Getter::make(Value::table({ "n": Value::null() }), KeyPath::root())
  // 键存在（哪怕值是 null）不算缺失
  assert_eq(get.fetch_opt("n") is Some(_), true)
  assert_eq(get.fetch_opt("absent") is None, true)
  let mismatched = Getter::make(Value::int(1L), KeyPath::root())
  // 路径撞上非 Table：原样抛 TypeMismatch，不是缺失
  let message = try {
    let _ = mismatched.fetch_opt("a")
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'a': expected Table, got Int")
}

///|
test "or_missing falls back only on missing keys" {
  let get = Getter::make(Value::table({ "n": Value::int(7L) }), KeyPath::root())
  assert_eq(or_missing("n", 0L, t => get.int(t)), 7L)
  assert_eq(or_missing("absent", 0L, t => get.int(t)), 0L)
  let message = try {
    let _ = or_missing("n", "d", t => get.string(t))
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'n': expected Str, got Int")
}
