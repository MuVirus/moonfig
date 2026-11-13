///|
/// moonfig 示例：手写 `FromConfig`，字段的配置键写在提取调用里。
///
/// 运行：`moon run examples/from_config`
///
/// 每个字段一次 `get.*` 调用，配置键就是参数：改名、默认值、可选字段和
/// 嵌套结构体都写在同一个结构体字面量里。

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat}

///|
/// 嵌套结构体同样手写：`get.nested("pool")` 把子树交给它
struct PoolCfg {
  size : Int32
  timeout_ms : Int64
}

///|
impl @config.FromConfig for PoolCfg with fn from_config(get : @config.Getter) -> PoolCfg raise @config.ConfigError {
  { size: get.int32("size"), timeout_ms: get.int("timeout_ms"), }
}

///|
struct ServerCfg {
  host : String
  port : Int64
  retry : Int32
  comment : String?
  pool : PoolCfg
}

///|
impl @config.FromConfig for ServerCfg with fn from_config(get : @config.Getter) -> ServerCfg raise @config.ConfigError {
  {
    host: get.string("db-host"), // 配置键 db-host，字段名 host
    port: get.int("port"), // 原生 Int64，大整数不丢
    retry: get.int32_or("retry", 3), // 缺失时用 3，类型不符仍报错
    comment: get.opt_string("comment"), // 缺失或 null 都是 None
    pool: get.nested("pool"), // 嵌套走 PoolCfg 的 from_config
  }
}

///|
fn main raise {
  let minimal =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 5432,
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  // 顶层提取：下面的配置键都相对 "server" 这棵子树
  let cfg = Config::new()
    .add(StringSource::new(minimal, JsonFormat::new()))
    .build()
  let srv : ServerCfg = cfg.get_struct("server")
  println(
    "host=\{srv.host} port=\{srv.port} retry=\{srv.retry} comment=\{srv.comment.unwrap_or("None")} pool=\{srv.pool.size}/\{srv.pool.timeout_ms}",
  )

  // 预期失败：retry 写成字符串，有默认值也不兜底；错误只在这一处处理
  let wrong_retry =
    #|{
    #|  "server": {
    #|    "db-host": "localhost",
    #|    "port": 5432,
    #|    "retry": "5",
    #|    "pool": { "size": 8, "timeout_ms": 30000 }
    #|  }
    #|}
  try {
    let cfg = Config::new()
      .add(StringSource::new(wrong_retry, JsonFormat::new()))
      .build()
    let srv : ServerCfg = cfg.get_struct("server")
    println("unexpected: retry=\{srv.retry}")
  } catch {
    e => println("wrong retry -> \{e}")
  }
}
