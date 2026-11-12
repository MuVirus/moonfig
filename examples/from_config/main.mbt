///|
/// moonfig 示例：手写 `FromConfig`，把字段标签内联在调用点。
///
/// 运行：`moon run examples/from_config`
///
/// `derive(FromJson)` 零样板，但字段名必须和配置键一致、没有默认值、64 位
/// 字段要包 `Int64Text`。需要改名、缺省值、原生 `Int64` 或逐字段控制时，
/// 手写 `FromConfig`：每个字段一行，配置键就写在调用点上。
///
/// 嵌套结构体可以两条路混搭：手写的用 `get.nested` 递归，
/// derive(FromJson) 的用 `@jsonfmt.json_field` 一行委托。

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat, json_field}

///|
/// 嵌套结构体，继续用 derive(FromJson)：字段名等于配置键，零样板
#derive(@json.FromJson)
struct DbCfg {
  host : String
  port : Int32
}

///|
pub extend DbCfg with @json.FromJson::{from_json}

///|
/// 嵌套结构体，手写 `FromConfig`：字段名和配置键不同，需要标签
struct PoolCfg {
  size : Int32
  timeout_ms : Int64
}

///|
impl @config.FromConfig for PoolCfg with fn from_config(get : @config.Getter) -> PoolCfg raise @config.ConfigError {
  { size: get.int32("size"), timeout_ms: get.int("timeout_ms"), }
}

///|
/// 顶层结构体：改名、原生 64 位、缺省值、可选字段、数组都在这里
struct ServerCfg {
  host : String
  port : Int64
  retry : Int32
  comment : String?
  tags : Array[String]
  db : DbCfg
  pool : PoolCfg
}

///|
impl @config.FromConfig for ServerCfg with fn from_config(get : @config.Getter) -> ServerCfg raise @config.ConfigError {
  {
    host: get.string("db-host"), // 标签改名：配置键 db-host，字段名 host
    port: get.int("port"), // 原生 Int64，不用 Int64Text，大整数不丢
    retry: get.int32_or("retry", 3), // 缺失用默认值；写错类型仍报错
    comment: get.opt_string("comment"), // 缺失或 null 都是 None
    tags: get.strings("tags"), // 数组
    db: json_field(get, "db"), // 嵌套走 derive(FromJson)
    pool: get.nested("pool"), // 嵌套继续走手写 FromConfig
  }
}

///|
/// Option 的展示文本（Option 的 Show 已弃用，不直接插值）
fn opt_text(option : String?) -> String {
  match option {
    None => "None"
    Some(s) => "\{s}"
  }
}

///|
/// 数组拼成紧凑文本（直接插值会用到已弃用的 Show）
fn tags_text(tags : Array[String]) -> String {
  "[\{tags.join(", ")}]"
}

///|
/// 提取整个 ServerCfg：成功带字段，失败带错误原文
fn extract_server(text : String) -> String {
  try {
    let cfg = Config::new()
      .add(StringSource::new(text, JsonFormat::new()))
      .build()
    let srv : ServerCfg = cfg.get_struct("server")
    let comment = opt_text(srv.comment)
    let tags = tags_text(srv.tags)
    "host=\{srv.host} port=\{srv.port} retry=\{srv.retry} comment=\{comment} tags=\{tags} db=\{srv.db.host}:\{srv.db.port} pool=\{srv.pool.size}/\{srv.pool.timeout_ms}"
  } catch {
    e => "error: \{e}"
  }
}

///|
fn main {
  let good =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 5432,
    #|    "retry": 5,
    #|    "comment": "primary",
    #|    "tags": ["edge", "eu"],
    #|    "db": { "host": "db.internal", "port": 5432 },
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  let minimal =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 5432,
    #|    "tags": [],
    #|    "db": { "host": "db.internal", "port": 5432 },
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  let missing_host =
    #|{
    #|  "server": {
    #|    "port": 5432,
    #|    "tags": [],
    #|    "db": { "host": "db.internal", "port": 5432 },
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  let wrong_retry =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 5432,
    #|    "retry": "5",
    #|    "tags": [],
    #|    "db": { "host": "db.internal", "port": 5432 },
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  let big_port =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 9007199254740993,
    #|    "retry": 5,
    #|    "tags": [],
    #|    "db": { "host": "db.internal", "port": 5432 },
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}

  println("== 手写 FromConfig 提取 ==")
  println("完整配置     -> \{extract_server(good)}") // 字段齐全
  println("缺省值       -> \{extract_server(minimal)}") // retry=3，comment=None
  println("缺必填字段   -> \{extract_server(missing_host)}") // 缺 db-host
  println("默认值不兜底 -> \{extract_server(wrong_retry)}") // retry 写错类型
  println("大整数不丢   -> \{extract_server(big_port)}") // 9007199254740993 原样保留
}
