///|
/// 合并两层：两边都是表就逐 key 合，其它情况按路径上的策略或「后加的赢」。
///
/// - 都是 `Table` → 递归逐 key 合并，表节点取 `over` 的 origin
/// - 路径声明了 `Append` / `Union` → 按策略合并，见 `merge_listed`
/// - 其它 → `over` 覆盖 `base`；数组**整体替换**，不拼接
fn merge_at(
  base : Value,
  over : Value,
  path : KeyPath,
  strategies : Map[String, MergeStrategy],
) -> Value raise ConfigError {
  match (base.kind, over.kind) {
    (ValueKind::Table(a), ValueKind::Table(b)) =>
      {
        kind: ValueKind::Table(merge_table(a, b, path, strategies)),
        origin: over.origin,
      }
    _ =>
      if strategies.is_empty() {
        over
      } else {
        match strategies.get(path.to_string()) {
          Some(Append) => merge_listed(append_elems, base, over, path)
          Some(Union) => merge_listed(union_elems, base, over, path)
          _ => over
        }
      }
  }
}

///|
/// 逐 key 合并两张表：b 的 key 赢，两边都是表时继续往下合。
fn merge_table(
  base : Map[String, Value],
  over : Map[String, Value],
  path : KeyPath,
  strategies : Map[String, MergeStrategy],
) -> Map[String, Value] raise ConfigError {
  let result = base.copy()
  for key, over_value in over {
    result[key] = match result.get(key) {
      Some(base_value) =>
        merge_at(base_value, over_value, path.add(key), strategies)
      None => over_value
    }
  }
  result
}

///|
/// 按给出的拼接方式合并列表键的两侧：`null` 算缺席，返回另一侧；两侧都
/// 不是数组抛 `MergeConflict`；都是数组拼起来，节点取 `over` 的 origin
/// （与表节点一致），元素各自保留原来那层的 origin。
fn merge_listed(
  combine : (Array[Value], Array[Value]) -> Array[Value],
  base : Value,
  over : Value,
  path : KeyPath,
) -> Value raise ConfigError {
  match (base.kind, over.kind) {
    (ValueKind::Null, _) => over
    (_, ValueKind::Null) => base
    (ValueKind::Array(base_elems), ValueKind::Array(over_elems)) =>
      {
        kind: ValueKind::Array(combine(base_elems, over_elems)),
        origin: over.origin,
      }
    _ =>
      raise ConfigError::MergeConflict(
        path.to_string(),
        base.kind.name(),
        over.kind.name(),
      )
  }
}

///|
/// 拼接两侧元素，`base` 在前 `over` 在后。
fn append_elems(base : Array[Value], over : Array[Value]) -> Array[Value] {
  let result = base.copy()
  for elem in over {
    result.push(elem)
  }
  result
}

///|
/// 并集：两侧元素按出现顺序排，重复的保留首次出现。
fn union_elems(base : Array[Value], over : Array[Value]) -> Array[Value] {
  let result : Array[Value] = []
  for elems in [base, over] {
    for elem in elems {
      if !result.contains(elem) {
        result.push(elem)
      }
    }
  }
  result
}
