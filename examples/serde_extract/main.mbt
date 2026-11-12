///|
/// moonfig 示例：serde 类型直接从配置提取。
///
/// 运行：`moon run examples/serde_extract`
///
/// 类型用 serde 的 `#serde.derive(Deserialize)` 属性描述，`Deserialize`
/// 由 serde 的生成器生成到 `types_derive.mbt`（已提交；本包的 `moon.pkg`
/// 里声明了 `dev_build`，`moon check` / `moon test` 会先自动重跑生成器）。
/// moonfig 的 `Value` 树作为 serde 的一个格式后端参与提取——类型不感知
/// 配置来源，配置不感知类型形状。

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat}

///|
/// Option 字段的展示文本（Option 的 Show 已弃用，不直接插值）
fn opt_text(option : String?) -> String {
  match option {
    None => "None"
    Some(s) => "\{s}"
  }
}

///|
/// 提取整个 AppCfg：成功带字段，失败带错误原文
fn extract_app(text : String) -> String {
  try {
    let cfg = Config::new()
      .add(StringSource::new(text, JsonFormat::new()))
      .build()
    let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
    let comment = opt_text(app.db.comment)
    "name=\{app.name} retries=\{app.retries} db=\{app.db.host}:\{app.db.port} comment=\{comment}"
  } catch {
    e => "error: \{e}"
  }
}

///|
/// 数组字段单独打印：`Array::join` 拼成紧凑文本（直接插值会用到已弃用的 Show）
fn extract_tags(text : String) -> String {
  try {
    let cfg = Config::new()
      .add(StringSource::new(text, JsonFormat::new()))
      .build()
    let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
    "[\{app.tags.join(", ")}]"
  } catch {
    e => "error: \{e}"
  }
}

///|
fn main {
  let good =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "retries": 5,
    #|    "tags": ["edge", "eu"],
    #|    "db": { "db-host": "localhost", "port": 5432, "comment": "primary" }
    #|  }
    #|}
  let no_comment =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "retries": 5,
    #|    "tags": [],
    #|    "db": { "db-host": "localhost", "port": 5432 }
    #|  }
    #|}
  let missing_host =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "retries": 5,
    #|    "tags": [],
    #|    "db": { "port": 5432 }
    #|  }
    #|}
  let wrong_type =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "retries": "5",
    #|    "tags": [],
    #|    "db": { "db-host": "h", "port": 5432 }
    #|  }
    #|}
  let big_port =
    #|{
    #|  "app": {
    #|    "name": "api",
    #|    "retries": 5,
    #|    "tags": [],
    #|    "db": { "db-host": "h", "port": 9007199254740993 }
    #|  }
    #|}

  println("== serde 类型直接从配置提取 ==")
  println("完整配置     -> \{extract_app(good)}") // name=api retries=5 db=localhost:5432 comment=primary
  println("缺失可选字段 -> \{extract_app(no_comment)}") // comment 缺失，None
  println("缺必填字段   -> \{extract_app(missing_host)}") // error: missing key 'app.db.db-host'
  println("类型写错     -> \{extract_app(wrong_type)}") // error: key 'app.retries': expected Int, got Str
  println("大整数不丢   -> \{extract_app(big_port)}") // port=9007199254740993，超出 Double 精确范围也按原文还原
  println("")
  println("== 数组字段 ==")
  println("tags -> \{extract_tags(good)}") // [edge, eu]
}
