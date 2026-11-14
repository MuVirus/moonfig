///|
/// moonfig 提取性能对比：derive(FromJson)、手写 FromConfig、serde_bridge。
///
/// 运行：`moon bench benchmarks`
///
/// 每个 benchmark 的闭包里只放提取，JSON 解析和 Config 构建在闭包外完成；
/// `e2e` 那一组把解析、构建、提取一起算，用来看真实调用成本。
///
/// 三套结构体字段类型一致（`String` / `Int32` / `Array[String]` / 可选的
/// `String?`），只比较提取路径本身的开销。每个字段都会被 checksum 读到，
/// 既防止编译器把字段裁掉，也让三条路径做同样的读取工作。

///|
let sample =
  #|{
  #|  "app": {
  #|    "name": "api",
  #|    "retries": 5,
  #|    "tags": ["edge", "eu"],
  #|    "db": { "host": "localhost", "port": 5432, "comment": "primary" }
  #|  }
  #|}

///|
fn parse(text : String) -> @config.Config {
  @config.Config::new()
  .add(@config.StringSource::new(text, @jsonfmt.JsonFormat::new()))
  .build() catch {
    error => abort("bad benchmark fixture: \{error}")
  }
}

///|
let fixture : @config.Config = parse(sample)

///|
fn opt_len(text : String?) -> Int32 {
  match text {
    None => 0
    Some(value) => value.length()
  }
}

///|
/// derive(FromJson) 路径的结构体
#derive(@json.FromJson)
struct JsonDb {
  host : String
  port : Int32
  comment : String?
}

///|
pub extend JsonDb with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
struct JsonApp {
  name : String
  retries : Int32
  tags : Array[String]
  db : JsonDb
}

///|
pub extend JsonApp with @json.FromJson::{from_json}

///|
/// 手写 FromConfig 路径的结构体
struct HandDb {
  host : String
  port : Int32
  comment : String?
}

///|
impl @config.FromConfig for HandDb with fn from_config(get : @config.Getter) -> HandDb raise @config.ConfigError {
  {
    host: get.string("host"),
    port: get.int32("port"),
    comment: get.opt_string("comment"),
  }
}

///|
struct HandApp {
  name : String
  retries : Int32
  tags : Array[String]
  db : HandDb
}

///|
impl @config.FromConfig for HandApp with fn from_config(get : @config.Getter) -> HandApp raise @config.ConfigError {
  {
    name: get.string("name"),
    retries: get.int32("retries"),
    tags: get.strings("tags"),
    db: get.nested("db"),
  }
}

///|
fn extract_derive(cfg : @config.Config) -> JsonApp {
  @jsonfmt.extract_from(cfg, "app") catch {
    error => abort("derive(FromJson) extraction failed: \{error}")
  }
}

///|
fn extract_hand(cfg : @config.Config) -> HandApp {
  cfg.get_struct("app") catch {
    error => abort("FromConfig extraction failed: \{error}")
  }
}

///|
fn extract_serde(cfg : @config.Config) -> @extract.SerdeApp {
  @serde_bridge.extract_serde_from(cfg, "app") catch {
    error => abort("serde extraction failed: \{error}")
  }
}

///|
fn checksum_derive(app : JsonApp) -> Int32 {
  app.name.length() +
  app.retries +
  app.tags.length() +
  app.db.host.length() +
  app.db.port +
  opt_len(app.db.comment)
}

///|
fn checksum_hand(app : HandApp) -> Int32 {
  app.name.length() +
  app.retries +
  app.tags.length() +
  app.db.host.length() +
  app.db.port +
  opt_len(app.db.comment)
}

///|
fn checksum_serde(app : @extract.SerdeApp) -> Int32 {
  app.name.length() +
  app.retries +
  app.tags.length() +
  app.db.host.length() +
  app.db.port +
  opt_len(app.db.comment)
}

///|
test "bench extract: derive(FromJson)" (it : @bench.T) {
  it.bench(fn() { it.keep(checksum_derive(extract_derive(fixture))) })
}

///|
test "bench extract: FromConfig" (it : @bench.T) {
  it.bench(fn() { it.keep(checksum_hand(extract_hand(fixture))) })
}

///|
test "bench extract: serde_bridge" (it : @bench.T) {
  it.bench(fn() { it.keep(checksum_serde(extract_serde(fixture))) })
}

///|
test "bench e2e: derive(FromJson)" (it : @bench.T) {
  it.bench(fn() {
    let cfg = parse(sample)
    it.keep(checksum_derive(extract_derive(cfg)))
  })
}

///|
test "bench e2e: FromConfig" (it : @bench.T) {
  it.bench(fn() {
    let cfg = parse(sample)
    it.keep(checksum_hand(extract_hand(cfg)))
  })
}

///|
test "bench e2e: serde_bridge" (it : @bench.T) {
  it.bench(fn() {
    let cfg = parse(sample)
    it.keep(checksum_serde(extract_serde(cfg)))
  })
}
