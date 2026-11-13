///|
/// moonfig 示例：serde 描述的类型直接从配置提取。
///
/// 运行：`moon run examples/serde_extract`
///
/// 类型只实现 serde 的 `Deserialize`（由 `#serde.derive` 生成），moonfig 的
/// `Value` 树作为 serde 的后端参与提取：类型不感知配置来源，配置不感知类型形状。

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat}

///|
fn main raise {
  let full =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "tags": ["edge", "eu"],
    #|    "db": { "db-host": "localhost", "port": 5432 }
    #|  }
    #|}
  // 一个调用完成提取："app" 是配置里的根键，db-host 对应 DbCfg.host
  let cfg = Config::new()
    .add(StringSource::new(full, JsonFormat::new()))
    .build()
  let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
  println(
    "name=\{app.name} db=\{app.db.host}:\{app.db.port} tags=\{app.tags.join(", ")}",
  )

  // 预期失败：缺必填字段，错误只在这一处处理
  let missing_host =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "tags": ["edge", "eu"],
    #|    "db": { "port": 5432 }
    #|  }
    #|}
  try {
    let cfg = Config::new()
      .add(StringSource::new(missing_host, JsonFormat::new()))
      .build()
    let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
    println("unexpected: \{app.db.host}")
  } catch {
    e => println("missing db-host -> \{e}")
  }
}
