// 类型侧：用 serde 的属性描述形状，`Deserialize` 由 serde 的生成器生成到
// `types_derive.mbt`（已提交）。moonfig 只消费 `Deserialize` trait。

///|
/// 嵌套结构体：`db-host` 展示标签改名，`Int64` 展示 64 位精确读
#serde.derive(Deserialize)
pub(all) struct DbCfg {
  /// 配置键是 `db-host`，字段名与配置键解耦
  #serde.rename("db-host")
  host : String
  /// 9007199254740993 这样超出 Double 精确范围的整数按原文还原
  port : Int64
  /// 缺失或显式 null 都是 None
  comment : String?
}

///|
/// 顶层结构体：数组走 serde 的 blanket impl，未知键自动跳过
#serde.derive(Deserialize)
pub(all) struct AppCfg {
  name : String
  retries : Int32
  tags : Array[String]
  db : DbCfg
}
