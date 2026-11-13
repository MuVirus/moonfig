// 类型侧：只声明形状，`Deserialize` 由 serde 的生成器生成到
// `types_derive.mbt`（已提交）。moonfig 只消费 `Deserialize` trait。

///|
/// 嵌套结构体：`#serde.rename` 让配置键和字段名解耦
#serde.derive(Deserialize)
pub(all) struct DbCfg {
  #serde.rename("db-host")
  host : String
  port : Int64
}

///|
/// 顶层结构体：字段名就是配置键，数组直接读
#serde.derive(Deserialize)
pub(all) struct AppCfg {
  name : String
  tags : Array[String]
  db : DbCfg
}
