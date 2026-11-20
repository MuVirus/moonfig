///|
/// moonfig 示例：用 `derive(FromJson)` 把配置子树提取成结构体。
///
/// 运行：`moon run examples/from_json_extract`
///
/// 字段名与配置键一致时，给类型加 `#derive(@json.FromJson)`，再用
/// `extract_from` 一次解码；类型不符时报错，不做隐式转换。

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat, extract_from}

///|
/// 字段名对应 `db` 子树下的 `port` 和 `name`
#derive(@json.FromJson)
struct DbCfg {
  port : Int32
  name : String
}

///|
pub extend DbCfg with @json.FromJson::{from_json}

///|
fn main raise {
  let cfg = Config::new()
    .add(
      StringSource::new(
        "{\"db\":{\"port\":5432,\"name\":\"main\"}}",
        JsonFormat::new(),
      ),
    )
    .build()

  // "db" 是配置里的根键，字段名对应子树下的键
  let db : DbCfg = extract_from(cfg, "db")
  println("port = \{db.port}, name = \{db.name}")

  // 预期失败：port 写成字符串，FromJson 不做隐式转换；错误只在这一处处理
  let textual = Config::new()
    .add(
      StringSource::new(
        "{\"db\":{\"port\":\"5432\",\"name\":\"main\"}}",
        JsonFormat::new(),
      ),
    )
    .build()
  try {
    let db : DbCfg = extract_from(textual, "db")
    println("unexpected: port = \{db.port}")
  } catch {
    e => println("string port -> \{e}")
  }
}
