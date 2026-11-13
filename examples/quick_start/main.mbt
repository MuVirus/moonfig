///|
/// moonfig 示例：两层来源叠在一起，后加的只覆盖同名键。
///
/// 运行：`moon run examples/quick_start`

///|
using @config {type Config, type StringSource}

///|
using @jsonfmt {type JsonFormat}

///|
fn main raise {
  let cfg = Config::new()
    .add(
      StringSource::new(
        "{\"db\":{\"host\":\"localhost\",\"port\":5432}}",
        JsonFormat::new(),
      ),
    )
    .add(StringSource::new("{\"db\":{\"port\":6543}}", JsonFormat::new()))
    .build()

  println("db.host = \{cfg.get_string("db.host")}")
  println("db.port = \{cfg.get_int("db.port")}")
}
