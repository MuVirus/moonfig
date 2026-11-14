// JSON 严格类型测试：数字、浮点、字符串之间不做隐式转换。
//
// 这里只依赖 core 的 `Value` 和 json_format 自己的 `extract`，
// 不经过上层的 Config / StringSource。

///|
/// 把 JSON text解码成底层 `Value`，后面的测试统一走 `extract(Value)`。
fn json_value(text : Bytes) -> @config.Value raise @config.ConfigError {
  @json_format.JsonFormat::new().decode(text)
}

///|
/// 提取到 `Int` 字段；成功时把值也带回来，失败时给错误原文
fn int_extract_result(v : @config.Value) -> String {
  try {
    let got : IntValue = @json_format.extract(v)
    "no error: value = \{got.value}"
  } catch {
    error => error.to_string()
  }
}

///|
/// 提取到 `String` 字段；成功时把值也带回来，失败时给错误原文
fn text_extract_result(v : @config.Value) -> String {
  try {
    let got : TextValue = @json_format.extract(v)
    "no error: value = \"\{got.value}\""
  } catch {
    error => error.to_string()
  }
}

///|
#derive(@json.FromJson)
struct IntValue {
  value : Int32
}

///|
pub extend IntValue with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
struct TextValue {
  value : String
}

///|
pub extend TextValue with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
struct FloatValue {
  value : Double
}

///|
pub extend FloatValue with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
struct Int64Value {
  value : @json_format.Int64Text
}

///|
pub extend Int64Value with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
struct UInt64Value {
  value : @json_format.UInt64Text
}

///|
pub extend UInt64Value with @json.FromJson::{from_json}

///|
/// 只用来验证直接写 `Int64` 时字符串来源也会被拒绝
#derive(@json.FromJson)
#warnings("-unused_field")
struct RawInt64Value {
  value : Int64
}

///|
pub extend RawInt64Value with @json.FromJson::{from_json}

///|
/// 只用来验证直接写 `UInt64` 时字符串来源也会被拒绝
#derive(@json.FromJson)
#warnings("-unused_field")
struct RawUInt64Value {
  value : UInt64
}

///|
pub extend RawUInt64Value with @json.FromJson::{from_json}

///|
/// 探针的失败不能掩盖后面的字段：BigInt 靠标准库解析字符串通过正常解码，
/// 它在字符串探针里的失败曾经吞掉探针，让后面的 `"NaN"` 静默落进 Double。
#derive(@json.FromJson)
#warnings("-unused_field")
struct BigIntDoubleValue {
  big : @bigint.BigInt
  d : Double
}

///|
pub extend BigIntDoubleValue with @json.FromJson::{from_json}

///|
/// 字段顺序反过来也要一样拒绝：探针逐节点跑，和声明顺序无关
#derive(@json.FromJson)
#warnings("-unused_field")
struct DoubleBigIntValue {
  d : Double
  big : @bigint.BigInt
}

///|
pub extend DoubleBigIntValue with @json.FromJson::{from_json}

///|
/// `Char` 只收单字符字符串，同样会在字符串探针里先失败，曾经掩盖后面字段
#derive(@json.FromJson)
#warnings("-unused_field")
struct CharDoubleValue {
  c : Char
  d : Double
}

///|
pub extend CharDoubleValue with @json.FromJson::{from_json}

///|
/// 只用来验证单独的 BigInt 字段在严格类型下的行为
#derive(@json.FromJson)
#warnings("-unused_field")
struct BigIntValue {
  big : @bigint.BigInt
}

///|
pub extend BigIntValue with @json.FromJson::{from_json}

///|
/// 只用来验证 Char 字段不被字符串探针误伤
#derive(@json.FromJson)
#warnings("-unused_field")
struct CharValue {
  c : Char
}

///|
pub extend CharValue with @json.FromJson::{from_json}

///|
/// float提取成 `Int` 必须报错，不能静默截断成integer部分。
test "JSON float cannot be extracted as Int" {
  let v = json_value(b"{\"value\": 3.14}")
  assert_eq(int_extract_result(v), "key 'value': expected Int, got Float")
}

///|
/// 负float同样不能截断。
test "negative JSON float cannot be extracted as Int" {
  let v = json_value(b"{\"value\": -3.99}")
  assert_eq(int_extract_result(v), "key 'value': expected Int, got Float")
}

///|
/// 值是integer、但写法是浮点（小数点或指数）时仍是 Float，不能进 Int 字段。
test "integral JSON floats cannot be extracted as Int" {
  for text in [b"{\"value\": 1.0}", b"{\"value\": 1e2}", b"{\"value\": -0.0}"] {
    assert_eq(
      int_extract_result(json_value(text)),
      "key 'value': expected Int, got Float",
    )
  }
}

///|
/// 9007199254740993 超出 Double 的精确integer范围，端到端都要保原文。
test "big int stays exact in Int64Text and UInt64Text" {
  let v = json_value(b"{\"value\": 9007199254740993}")
  let signed : Int64Value = @json_format.extract(v)
  assert_eq(signed.value.to_int64(), 9007199254740993L)
  let unsigned : UInt64Value = @json_format.extract(v)
  assert_eq(unsigned.value.to_uint64(), 9007199254740993UL)
}

///|
/// 大integer提取成 32 位 `Int` 应该报范围错误，而不是绕回或截断。
test "big int extracted as Int reports overflow" {
  let v = json_value(b"{\"value\": 9007199254740993}")
  assert_eq(
    int_extract_result(v),
    "parse error: key 'value' is out of range for Int",
  )
}

///|
/// 负数大integer同样按原文还原。
test "negative big int stays exact" {
  let v = json_value(b"{\"value\": -9007199254740993}")
  let signed : Int64Value = @json_format.extract(v)
  assert_eq(signed.value.to_int64(), -9007199254740993L)
}

///|
/// 超出 Int64 的integer在解析阶段就报错，不能静默截断。
test "integer beyond Int64 is rejected while parsing" {
  let message = try {
    ignore(json_value(b"{\"value\": 9223372036854775808}"))
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(
    message, "parse error: integer 9223372036854775808 exceeds Int64 range",
  )
}

///|
/// 数字来源不能提取成字符串，字符串来源不能提取成数字。
test "number and string do not cross in extraction" {
  let number = json_value(b"{\"value\": 5432}")
  assert_eq(text_extract_result(number), "key 'value': expected Str, got Int")
  let text = json_value(b"{\"value\": \"5432\"}")
  assert_eq(int_extract_result(text), "key 'value': expected Int, got Str")
}

///|
/// `Int32` 的精确边界：最大/最小值可提取，越界一位就报范围错误。
test "Int32 boundaries are strict" {
  assert_eq(
    int_extract_result(json_value(b"{\"value\": 2147483647}")),
    "no error: value = 2147483647",
  )
  assert_eq(
    int_extract_result(json_value(b"{\"value\": -2147483648}")),
    "no error: value = -2147483648",
  )
  assert_eq(
    int_extract_result(json_value(b"{\"value\": 2147483648}")),
    "parse error: key 'value' is out of range for Int",
  )
  assert_eq(
    int_extract_result(json_value(b"{\"value\": -2147483649}")),
    "parse error: key 'value' is out of range for Int",
  )
}

///|
/// 浮点字段也不接受字符串来源。
test "string cannot be extracted as Double" {
  let v = json_value(b"{\"value\": \"3.14\"}")
  let message = try {
    let got : FloatValue = @json_format.extract(v)
    "no error: value = \{got.value}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'value': expected Float, got Str")
}

///|
/// 标准库的 `Double::from_json` 接受字符串 `"NaN"` / `"Infinity"` / `"-Infinity"`，
/// 但配置里的字符串来源不该因此变成浮点。
test "string special floats cannot be extracted as Double" {
  for
    text in [
      b"{\"value\": \"NaN\"}", b"{\"value\": \"Infinity\"}", b"{\"value\": \"-Infinity\"}",
    ] {
    let v = json_value(text)
    let message = try {
      let got : FloatValue = @json_format.extract(v)
      "no error: value = \{got.value}"
    } catch {
      error => error.to_string()
    }
    assert_eq(message, "key 'value': expected Float, got Str")
  }
}

///|
/// 直接写 `Int64` / `UInt64` 时，标准库会解析字符串；这里也必须拒绝，
/// 否则字符串来源会绕过 `Int64Text` 的检查。
test "string cannot be extracted as raw Int64 or UInt64" {
  let v = json_value(b"{\"value\": \"5432\"}")
  let int_message = try {
    let got : RawInt64Value = @json_format.extract(v)
    "no error: value = \{got.value}"
  } catch {
    error => error.to_string()
  }
  assert_eq(int_message, "key 'value': expected Int64, got Str")

  let uint_message = try {
    let got : RawUInt64Value = @json_format.extract(v)
    "no error: value = \{got.value}"
  } catch {
    error => error.to_string()
  }
  assert_eq(uint_message, "key 'value': expected UInt64, got Str")
}

///|
/// `Int64Text` 只认integer形状：字符串和浮点都不收。
test "Int64Text rejects string and float sources" {
  let from_string = json_value(b"{\"value\": \"9007199254740993\"}")
  let string_message = try {
    let got : Int64Value = @json_format.extract(from_string)
    "no error: value = \{got.value.to_int64()}"
  } catch {
    error => error.to_string()
  }
  assert_eq(string_message, "key 'value': expected Int64, got Str")

  let from_float = json_value(b"{\"value\": 3.14}")
  let float_message = try {
    let got : Int64Value = @json_format.extract(from_float)
    "no error: value = \{got.value.to_int64()}"
  } catch {
    error => error.to_string()
  }
  assert_eq(float_message, "key 'value': expected Int64, got Float")

  let from_integral_float = json_value(b"{\"value\": 1.0}")
  let integral_float_message = try {
    let got : Int64Value = @json_format.extract(from_integral_float)
    "no error: value = \{got.value.to_int64()}"
  } catch {
    error => error.to_string()
  }
  assert_eq(integral_float_message, "key 'value': expected Int64, got Float")
}

///|
/// BigInt 字段在字符串探针里先失败（标准库把它当数字解析），但它的失败
/// 不能掩盖后面 Double 字段的 `"NaN"` ——曾经静默提取成功。
test "BigInt field failure does not mask later Double string probe" {
  let v = json_value(b"{\"big\": \"123\", \"d\": \"NaN\"}")
  let message = try {
    let got : BigIntDoubleValue = @json_format.extract(v)
    "no error: big = \{got.big}, d = \{got.d}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'big': expected BigInt, got Str")
}

///|
/// 字段顺序反过来也一样：探针按值树逐节点跑，`d` 的违规照常报出，
/// 不会被 `big` 的探针失败掩盖。
test "Double field violation is caught regardless of field order" {
  let v = json_value(b"{\"d\": \"NaN\", \"big\": \"123\"}")
  let message = try {
    let got : DoubleBigIntValue = @json_format.extract(v)
    "no error: d = \{got.d}, big = \{got.big}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'd': expected Float, got Str")
}

///|
/// `Char` 只收单字符字符串，在探针里同样先失败；它后面的字段不能被掩盖。
test "Char field failure does not mask later Double string probe" {
  let v = json_value(b"{\"c\": \"x\", \"d\": \"NaN\"}")
  let message = try {
    let got : CharDoubleValue = @json_format.extract(v)
    "no error: c = \{got.c}, d = \{got.d}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'd': expected Float, got Str")
}

///|
/// 字符串来源也不能被标准库解析成 BigInt：和 Int64 / UInt64 同一类隐式转换。
test "string cannot be extracted as BigInt" {
  let v = json_value(b"{\"big\": \"123\"}")
  let message = try {
    let got : BigIntValue = @json_format.extract(v)
    "no error: big = \{got.big}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'big': expected BigInt, got Str")
}

///|
/// BigInt 字段遇数字来源走的是正常解码：保持 64 位的改法提示。
test "BigInt field with number source keeps Int64Text guidance" {
  let v = json_value(b"{\"big\": 123}")
  let message = try {
    let got : BigIntValue = @json_format.extract(v)
    "no error: big = \{got.big}"
  } catch {
    error => error.to_string()
  }
  assert_eq(
    message, "parse error: key 'big' is a 64-bit integer: declare the struct field as Int64Text or use get_int",
  )
}

///|
/// `Char` 是字符串形态的字段：单字符字符串照常提取，探针不能误伤。
test "Char accepts single-character string source" {
  let v = json_value(b"{\"c\": \"x\"}")
  let got : CharValue = @json_format.extract(v)
  assert_eq(got.c, 'x')
}

///|
/// 探针要递归进容器：Map 值里的特殊浮点字符串一样不能落进 Double。
#derive(@json.FromJson)
#warnings("-unused_field")
struct MapFloatValue {
  m : Map[String, Double]
}

///|
pub extend MapFloatValue with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
#warnings("-unused_field")
struct MapIntValue {
  m : Map[String, Int32]
}

///|
pub extend MapIntValue with @json.FromJson::{from_json}

///|
#derive(@json.FromJson)
#warnings("-unused_field")
struct ArrayDoubleValue {
  arr : Array[Double]
}

///|
pub extend ArrayDoubleValue with @json.FromJson::{from_json}

///|
test "string NaN inside Map values cannot become Double" {
  let v = json_value(b"{\"m\": {\"k\": \"NaN\"}}")
  let message = try {
    let got : MapFloatValue = @json_format.extract(v)
    "no error: m[k] = \{got.m["k"]}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'm.k': expected Float, got Str")
}

///|
test "float inside Map values cannot be truncated into Int" {
  let v = json_value(b"{\"m\": {\"k\": 3.14}}")
  let message = try {
    let got : MapIntValue = @json_format.extract(v)
    "no error: m[k] = \{got.m["k"]}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'm.k': expected Int, got Float")
}

///|
test "string NaN inside Array elements cannot become Double" {
  let v = json_value(b"{\"arr\": [\"NaN\"]}")
  let message = try {
    let got : ArrayDoubleValue = @json_format.extract(v)
    "no error: arr[0] = \{got.arr[0]}"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'arr.0': expected Float, got Str")
}

///|
/// json_field 的组合测试：derive(FromJson) 的子结构体作为 FromConfig 的一个字段
#derive(@json.FromJson)
struct DerivedDb {
  host : String
}

///|
pub extend DerivedDb with @json.FromJson::{from_json}

///|
struct MixedServer {
  host : String
  db : DerivedDb
}

///|
impl @config.FromConfig for MixedServer with fn from_config(
  get : @config.Getter,
) -> MixedServer raise @config.ConfigError {
  { host: get.string("db-host"), db: @json_format.json_field(get, "db"), }
}

///|
test "json_field delegates to derive(FromJson) with prefixed errors" {
  let v = json_value(b"{\"db-host\": \"h\", \"db\": {\"host\": \"d\"}}")
  let got : MixedServer = v.to_struct()
  assert_eq(got.host, "h")
  assert_eq(got.db.host, "d")

  let bad = json_value(b"{\"db-host\": \"h\", \"db\": {}}")
  let message = try {
    let _ : MixedServer = bad.to_struct()
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "missing key 'db.host': no source provides it")
}

///|
/// json_field 也走严格探针：子树里的字符串来源照样不能变数字
test "json_field keeps strict probes on the delegated subtree" {
  let v = json_value(b"{\"db-host\": \"h\", \"db\": {\"host\": \"NaN\"}}")
  let got : MixedServer = v.to_struct()
  assert_eq(got.db.host, "NaN")

  let numeric = json_value(b"{\"db-host\": \"h\", \"db\": {\"host\": 5}}")
  let message = try {
    let _ : MixedServer = numeric.to_struct()
    "no error"
  } catch {
    error => error.to_string()
  }
  assert_eq(message, "key 'db.host': expected Str, got Int")
}
