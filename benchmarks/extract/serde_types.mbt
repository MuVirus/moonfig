// 三套提取路径使用同一份配置形状，字段类型也保持一致，避免把类型差异
// 算进提取开销。`Deserialize` 由 serde 的生成器生成到 `serde_types_derive.mbt`。

///|
/// serde 类型：只描述形状，不感知 moonfig
#serde.derive(Deserialize)
pub(all) struct SerdeDb {
  host : String
  port : Int32
  comment : String?
}

///|
#serde.derive(Deserialize)
pub(all) struct SerdeApp {
  name : String
  retries : Int32
  tags : Array[String]
  db : SerdeDb
}
