# moonfig 路线图

记录「按什么顺序做、每部分做完能验收什么」，不是契约，可以随时改。
README 的路线图表是公开摘要，状态和条目与本文保持同步。

设计文档见 [docs/design/design.zh.md](../design/design.zh.md)。

状态分三档：✅ 已完成（进入维护）、🚧 进行中、⬜ 未进行。

---

## 核心　✅

**方向**：配置只在内存里存在——统一表示、按键合并、按 key 取值。不接触任何外部环境，因此在所有 target 上都能编译。

- [x] `Value` / `ValueKind`：一份表示覆盖所有格式的配置值
- [x] 点号路径取值
- [x] 合并规则：按键合并、数组整体替换
- [x] `Config` 构建器与 `get_string` / `get_int` / `get_bool` / `get_float`
- [x] 错误处理：`MissingKey` / `TypeMismatch` / `ParseError`
- [x] 按结构体取值（`FromConfig` / `derive(FromJson)`）
- [x] Source 追踪：`origin_of` / `origins` 查某个键最终来自哪一层，见 [sources.zh.md](../design/sources.zh.md#来源追踪)

### 后续

核心功能已完成；下面几条是维护期的增强。

- [ ] 错误来源查询：`origin_of_error(cfg, err)` 返回 `ConfigError` 对应的层，不改错误变体
- [ ] 结构化解析错误：解析器的原因和位置保留为字段，只在 `Show` 里渲染
- [ ] 取值错误带位置：`TypeMismatch` / `InvalidValue` 还没有源码区间，需要逐节点的 source map

**设计草案（结构化解析错误）**：

- `SourcePosition`：文本格式用 `Text(line, column)`，二进制格式用 `Bytes(offset)`。
- `ParseError(String)` 改成 `ParseError(String, SourcePosition?)`；`Show` 渲染成 `parse error at line L, column C: ...` 或 `at byte N: ...`。这是对 `ConfigError` 的破坏性变更，在 1.0 前做一次。
- 位置由格式给，来源标签（`file:...`）单独处理。构建期文件解析错误先由 `FileSource` 补 `file '<path>': `；统一的 `At(label, error)` 包装等这条开始时再定。
- 覆盖范围：先做 JSON / INI / .env / XML；TOML / YAML 取决于解析器；CBOR 字节偏移等上游 `CborError` 带位置。

**验收**：

- 来源查询：`catch` 后带键的错误能查到 `file:...` / `env:...`；构建期文件解析错误带 `file '<path>': `；`Show` 文本不变。
- 结构化解析错误：`catch` 后直接读位置字段，不用解析消息；JSON / INI / .env / XML 各有一条测试；`Show` 与 `errors.md` 一致。TOML / YAML 取决于解析器；CBOR 偏移不进这次验收。
- 取值错误位置：暂不启动；source map 设计出来之前没有验收。

### 最初的推进顺序

| 步 | 内容 | 验收 |
|---|---|---|
| 1 | `value.mbt` + `error.mbt` | 构造几个 `Value`，`debug_inspect` 形状对 |
| 2 | `merge.mbt` | 嵌套 `Table` 验证「后覆盖前、表逐 key 合、数组整体换」 |
| 3 | `source.mbt` + `config.mbt` | 两个 `MemorySource` 合起来，`get_*` 取到值；缺 key 报 `MissingKey` |
| 4 | `core/format/json_format/` | `Json` 文本 → `Value`，`Int` / `Float` 按有无小数点分开 |
| 5 | `extract` | 大整数端到端不丢 |

第 1~3 步做完，库就能用了（只是目前只有 `MemorySource`）。第 4、5 步各是独立的增量。

---

## 多格式　✅

**方向**：把各种格式的配置读成同一份 `Value`。格式之间可以自由替换，声明不用改。

- [x] JSON 文本（`core/format/json_format/` 包）
- [x] TOML（`MuVirus/moonfig-toml` 模块，`toml_format/` 包，依赖 `moonbit-community/toml`）
- [x] YAML（`MuVirus/moonfig-yaml` 模块，`yaml_format/` 包，依赖 `moonbit-community/yaml`）
- [x] `.env` 文本（`core/format/dotenv_format/` 包）
- [x] INI（`core/format/ini_format/` 包）
- [x] XML（`MuVirus/moonfig-xml` 模块，`xml_format/` 包，依赖 `Milky2018/xml`）
- [x] CBOR（`MuVirus/moonfig-cbor` 模块，`cbor_format/` 包，依赖 `2515050242/cbor`）

每加一种格式只做一件事：格式 → `Value`。合并、取值、校验都复用 `core/`，不为格式写第二套逻辑。

**格式说的是内容怎么写，Source 说的是从哪读。** `.env` 文件是一种格式，环境变量是一种 Source，两件事分开做：`EnvSource` 读环境变量时不需要知道它最后变成哪种格式。

**CBOR 是二进制格式，体积小，MCU 上常见。** 它也是检验 `Value` 表示能力的好例子——而这个检验的结果是：`Value` 原来少了一个形状。CBOR 有字节串，`Value` 原来没地方放它，所以 `ValueKind` 现在多了一个 `Bytes` 分支，`get_bytes` 把它原样取出来。其余的部分一一对得上：整数、字符串、数组、映射都不用特例。

**代价**：YAML、TOML、XML 和 CBOR 都依赖第三方解析器（`moonbit-community/yaml`、`moonbit-community/toml`、`Milky2018/xml`、`2515050242/cbor`）。模块依赖是该模块所有 package 依赖的并集，只分包不分模块的话，所有用户仍然会下载所有解析器。所以这四种格式各自成模块（仓库里在 `modules/moonfig-<name>/`，mooncakes 上是 `MuVirus/moonfig-<name>`），`moon add MuVirus/moonfig` 只依赖 `moonbitlang/x`。

**JSON、INI 和 `.env` 都是自己写的解析器，没有第三方依赖。** 三者都只用 MoonBit 标准库的包：JSON 走 `@json`，INI 和 `.env` 走 `@string` 里的 `parse_int64` / `parse_double`。INI 的类型猜法写在包的文档注释里：段落变层级、引号强制字符串、`;` 和 `#` 只在整行开头算注释；`.env` 的规则也写在包文档里：`export` 前缀可选、键名里的 `.` 变层级、单引号原样保留、双引号认转义、`#` 前面有空白才算行尾注释、不做变量展开。

**YAML 的语法交给 `moonbit-community/yaml`，本库只做 `Yaml` → `Value` 的转换。** 包文档写明了边界：只接受一个文档，空文件、空文档、只有注释的文件以及根节点为 `null` 的文件得到空表；根节点通常应是映射；整数超出 `Int64` 报错，不静默降级成浮点。

**TOML 的语法交给 `moonbit-community/toml`，本库只做 `TomlValue` → `Value` 的转换。** 包文档写明了边界：根节点必须是一张表；数组里混着不同类型时报错（TOML 要求同类型数组）；日期时间在 `Value` 里没有对应形状，按原文当字符串存；大整数保持 `Int64`。

**XML 的语法交给 `Milky2018/xml`，本库只做元素树 → `Value` 的转换。** XML 没有「键值」这回事，映射规则是本库定的，写在包文档里：根元素只是壳，子元素落在顶层；同名兄弟元素收成数组；属性在 `@` 前缀的键上；混合内容在 `#text` 上；CDATA 是字面文字，一定是字符串（这也是 XML 本身给「我要字符串」的办法）。

**CBOR 的语法交给 `2515050242/cbor`，本库只做 `CborValue` → `Value` 的转换。** 包文档写明了边界：根节点必须是一张映射；映射的键必须是文本字符串（CBOR 允许整数键，但配置里的键就是路径，路径是文本，整数键报错而不是偷偷转成字符串——那样整数键 `1` 会和字符串键 `"1"` 撞车）；标签被剥掉，只留里面的值（`Value` 没地方放标签）；`undefined` 报错（它和 `null` 不是一回事，`null` 落到 `Value::null()`）；字节串原样保留在 `Value::bytes` 里，`get_bytes` 取出原始字节；整数超出 `Int64` 报错，不静默降级成浮点；半精度和单精度浮点都展宽到 `Double`。

---

## 外部 Source　✅

**方向**：把外部世界读成配置。IO 只发生在这里，`core/` 那一层看不到文件和环境变量。

- [x] `FileSource`：读配置文件，格式交给上一层判断
- [x] `EnvSource`：读环境变量
- [x] `CliSource`：读命令行参数
- [x] 多个 Source 任意组合，优先级由加入顺序决定

### 环境变量是这一段里坑最多的

环境变量全是字符串：

- **类型推断必须在这一步做完**（`"5432"` → `Int`，`"true"` → `Bool`）。等到按结构体取值那步就晚了——标准库的 `Bool::from_json` 和 `Double::from_json` 都拒收字符串。
  - 落地方式：`core` 提供 `Value::from_literal`，`EnvSource` / `CliSource` 共用，不再各写一份。
- 分隔符约定：哪些字符分层、`_` 是否变 `.`、大小写是否敏感。
  - 落地方式：默认只有 `.` 分层；`with_separator("_")` 才让 `_` 分层，`with_separator("__")` 让单个 `_` 留在键名里。键名统一转小写；只差大小写的两个变量落到同一个路径时报错。
- 前缀、空值、列表值怎么处理。
  - 落地方式：构造时给前缀（`EnvSource::all()` 读全部）；空值是空字符串；列表不拆，整串留作字符串。

---

## 校验　✅

**方向**：配置读进来先验一遍，问题在启动时暴露，而不是在业务代码跑了一半才发现。

- [x] 必填项缺失
- [x] 取值范围校验（端口范围、字符串长度上限）
- [x] 未知键是否报错，做成开关
- [x] 校验规则由用户自己写
- [x] 校验失败给出键名、期望值、实际值

**落地方式**：按键用规则表，结构体用 `Validate`，两条路共用 `ConfigError` 和检查函数。必填项靠 `MissingKey`，未知键靠 `Rule::allowed_keys`（不写就不查）。详见 [validate.zh.md](../design/validate.zh.md)。

---

## 自动发现格式　✅

**方向**：给一个文件，不指定格式也能读进来。设计见 [format-detect.zh.md](../design/format-detect.zh.md)。

- [x] 按后缀判断（`.json` / `.toml` / `.yaml`）
- [x] 后缀缺失或不可靠时按内容判断
- [x] 判断失败时报错，并列出支持的格式
- [x] 解析失败时给出位置和原因

**落地方式**：`Format` 自己声明 `suffixes` / `sniff` / `decode_path`，`Detector` 负责归一化后缀、检查重复声明和按候选顺序做内容判断；`FileSource::auto` 负责把路径和字节交给检测器。已知后缀解析失败时直接报错，不换候选。

---

## 热更新（轮询）　✅

**方向**：配置文件变了就重新生效，不必重启进程。设计见 [hot-reload.zh.md](../design/hot-reload.zh.md)。

- [x] 监听文件变化：比较文件内容，不看 mtime
- [x] 重新读取并合并
- [x] 通过回调通知使用方
- [x] 新配置解析失败或校验不通过时保留旧配置

**落地方式**：`build_live()` 留下来源清单，`reload()` 成功才替换快照；`hot_reload` 的 `watch()` 登记回调，由调用方调用 `Watcher::poll()` 驱动一轮检测。`interval` 只是建议值，库不内建定时器。

**后续**：

- [ ] 内建定时器或 OS 文件事件（inotify / kqueue / ReadDirectoryChangesW）
- [ ] 环境变量和命令行的变化监听；目前没有可靠事件，仍手动 `reload()`

---

## 远程配置　⬜

**方向**：把远端当成一种 Source，而不是「一个 URL 下载器」。网络 IO 仍然只发生在 Source 层；拿回来的是字节或键值对，解析、合并、校验、来源追踪和热更新都复用已有路径。

**梯队**（按其他配置库的常见能力排序，不看 MoonBit 是否已有现成客户端）：

| 梯队 | 范围 | 验收 |
|---|---|---|
| 1 | 通用 HTTP/HTTPS 文件源：URL + 可选格式、认证头、超时重试、条件请求和本地缓存。也覆盖 Git raw、Spring Cloud Config（`Environment` 响应加一层薄映射），以及通过签名 URL 或公开 URL 访问的对象存储。 | 一个远端文件端到端跑通：`ETag` / `Last-Modified`、超时重试、断网时回退缓存、`origin` 说明 URL 和 revision；解析或校验失败保留旧快照。 |
| 2 | 远程 KV / 配置中心（带变更通知）：etcd、Consul、ZooKeeper、Nacos、Apollo、Firestore、NATS、Kubernetes ConfigMap / Secret。按键、前缀、namespace / group / profile 读取；watch、长轮询或 blocking query；本地快照和鉴权。 | 共享的「KV + watch」抽象至少接一个通用 KV（etcd 或 Consul）和一个配置中心（Nacos 或 Apollo）：本地快照、revision 单调、`origin` 带 key 和 revision、刷新失败保留旧快照。 |
| 3 | 云参数与密钥服务：AWS SSM Parameter Store / AppConfig / Secrets Manager、Azure App Configuration / Key Vault、GCP Runtime Config / Secret Manager、Vault / CredHub。云 IAM、签名或 OAuth、资源层级、版本 / 标签和密钥语义。 | 至少一个云服务用原生认证读到一个参数和一个密钥，支持版本 / 标签选择，错误和 `origin` 里脱敏。 |
| 4 | 存储型与特性开关来源：S3 / GCS / Blob / OSS 的 SDK 语义、Redis、SQL、MongoDB；LaunchDarkly / Unleash / Flagsmith / OpenFeature。多数是存储或运行时 targeting，不是静态配置。 | 等前三梯队之后决定：要么包一层现成客户端，要么在 `Value` / `Source` 模型不能干净表达时明确不做。 |

为什么这样排：

- Viper 的 remote provider 是 etcd / etcd3、Consul、Firestore、NATS，并带 `WatchRemoteConfig`，对应第二梯队。
- Spring Cloud Config 的客户端是 HTTP（第一梯队）；它的服务端仓库包括 Git、Vault、JDBC、Redis、S3、AWS SSM、GCP Secret Manager，后面的梯队由此而来。
- Apollo 和 Nacos 把 namespace / group、长轮询、本地快照做成标准；Kubernetes ConfigMap / Secret 是云原生的 KV + watch。
- 云参数与密钥服务多了 IAM、签名和密钥语义，所以排在通用 KV 之后。
- 特性开关是运行时 targeting 加流式更新，不是静态配置；等模型需要时再评估。

共性能力（接哪种远端都要有）：

- [ ] 本地缓存与兜底：上次成功的快照落盘，启动时远端不可达就用它；区分「缓存过期」和「没有缓存」。
- [ ] 刷新策略：轮询加条件请求、长轮询 / SSE / watch；revision 单调，避免旧响应覆盖新配置；失败时保留旧配置。
- [ ] 超时与重试：指数退避加抖动、可配置上限、可取消；区分可重试（5xx / 网络）与不可重试（4xx / 鉴权）。
- [ ] 认证与密钥：token 从环境变量或密钥链读取，不写进配置文件；日志、错误和 `origin` 里对敏感值脱敏。
- [ ] 一致性与完整性：TLS 校验、revision / checksum / 签名校验；先校验再替换快照。
- [ ] 来源可追踪：`origin` 报出远端类型、URL / key、revision 和拉取时间；与本地层按加入顺序合并。
- [ ] 可测试：在客户端之上包一层自己的传输 trait，测试不碰真实网络；平台后端（JS `fetch`、native、wasm）各自成包。

**落地方式（初稿）**：第一梯队新增 `http_source/`（或独立模块）；`Source` 产出 `Layer`，格式交给 `Format` / `Detector`。第二梯队新增可 watch 的 Source 抽象，缓存和快照替换仍复用 `Locator` / `LiveConfig`；每个 provider 是一个适配器。远端响应先落成 `Bytes` 或键值对，再走已有的解析和校验路径，不为远端写第二套合并逻辑。

**HTTP 客户端**：第一梯队用官方的 `moonbitlang/async/http` 就够，不需要第三方客户端。它覆盖 native、wasm1 和 js（已在 Windows native 上验证），所以远端源放在独立模块里，不进 `MuVirus/moonfig`：依赖树（`async`、经 OpenSSL 的 `tls`、`socket`、`gzip`）重，API 也仍是实验性的，而 `core/` 必须保持无依赖。该包声明 `supported_targets = "+native,+wasm,+js"`，因为 async 不支持 wasm-gc；这样 `moon check --target all` 会跳过它而不是失败。`Source::collect` 保持同步：异步的 `fetch()` 填缓存，`collect()` 读缓存，合并、校验和热更新都沿用现有形状。客户端只负责发请求；重试、退避、条件请求、缓存落盘和 `origin` 仍然由我们写。

**待定的设计问题**：

- 异步入口取什么形状：由调用方在运行时里驱动 `HttpSource::fetch()`、`collect()` 只读缓存；是否还需要一个异步门面（`fetch_all()` / `reload_async()`），留给第一梯队实现时决定。wasm-gc 没有 async 支持，远端模块要么跳过该 target，要么只提供读缓存。
- 协议适配放在一个通用 HTTP Source 上（配置中心只是不同的 URL 加解析），还是每种配置中心一个 Source；倾向后者，因为鉴权、分页和 watch 语义差异很大。
- 第二梯队的 watch 放在 `Source` 里，还是单独的 `Watcher` trait？`LiveConfig` 现在是轮询 `Locator`，推送式 watch 需要另一种形状。
- 特性开关是否算配置：它更像「运行时读值加流式更新」，先不做，等 `Value` / `Source` 模型需要时再评估。

**验收**：第一梯队是整个方向的入口；第二到第四梯队是独立增量，验收分别写在上表。

---

## 后续方向　⬜

- [ ] 加密存储：敏感配置字段的加密解析与安全存储。
- [ ] 预处理数据：对原有配置文本或者数据进行加工处理，不改变源数据。

---

## 依赖关系

```text
核心 ──→ 多格式 ──→ 外部 Source ──→ 自动发现格式 ──→ 热更新
  │
  └──→ 校验
```

「校验」和「多格式」互不阻塞，可以先做任意一个。「自动发现格式」要等格式多于一种才有意义。远程配置建立在外部 Source 和自动发现格式之上；刷新路径复用热更新。

文档体系怎么改见 [doc-system.zh.md](doc-system.zh.md)。

