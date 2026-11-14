# 结构体提取性能测试

比较三条“从配置提取到结构体”的路径：

| 路径 | 入口 | 实现方式 |
|---|---|---|
| `derive(FromJson)` | `@jsonfmt.extract_from(cfg, "app")` | `Value` → `Json`，再走标准库的 `FromJson`，外加严格类型探针 |
| 手写 `FromConfig` | `cfg.get_struct("app")` | 逐字段直接读 `Value`，没有 Json 往返 |
| `serde_bridge` | `@serde_bridge.extract_serde_from(cfg, "app")` | serde 的 `Deserialize` 直接消费 moonfig 的 `Value` |

三套结构体使用同一份配置、同样的字段类型（`String` / `Int32` / `Array[String]` / 可选 `String?`），只比较提取路径本身。每个字段都会被 checksum 读到，避免编译器把字段裁掉，也让三条路径做同样的读取工作。

## 运行

```sh
moon bench --release benchmarks
```

`benchmarks/` 是独立包，`moon test` 不会执行这些 benchmark；只在 `moon bench` 时编译运行。

## 两组口径

- **只提取**：`Config` 在 benchmark 闭包外构建好，闭包里只有提取。
- **e2e**：闭包里包含 JSON 解析、`Config` 构建和提取，接近一次真实调用。

## 本机结果

Windows / native release / MoonBit 0.1.20261104，三次运行的中位数：

| 路径 | 只提取 | e2e（解析 + 构建 + 提取） |
|---|---:|---:|
| `derive(FromJson)` | 58.9 µs | 69.6 µs |
| 手写 `FromConfig` | **8.6 µs** | **28.7 µs** |
| `serde_bridge` | 23.1 µs | 41.0 µs |

同一轮运行内比较才有意义，绝对值会随 CPU、负载和温度波动；`derive(FromJson)` 的波动尤其明显（三次在 36–68 µs 之间）。

## 怎么读

- **只提取**：手写 `FromConfig` 约比 `derive(FromJson)` 快 6–7 倍，比 `serde_bridge` 快约 2.5 倍。`derive` 要把整棵子树转成 `Json` 再解码，还要跑浮点 / 字符串 / 字节探针；手写路径直接读 `Value`，没有这些中间结构。
- **e2e**：解析和构建约占 10–20 µs，差距被摊薄到手写路径约快 2.4 倍（对 `derive`）、1.4 倍（对 serde）。如果每次启动只提取一两个结构体，三条路都够用；只有反复提取或 `Config` 已经构建好时，路径差异才明显。
- 这里只测运行时间，不测编译时间、代码体积或二进制大小；`serde` 还需要额外的生成器步骤。

## 文件

- [`extract_bench_test.mbt`](extract/extract_bench_test.mbt) —— 三套结构体和 6 个 benchmark
- [`serde_types.mbt`](extract/serde_types.mbt) —— serde 类型；`serde_types_derive.mbt` 由生成器产出
- [`moon.pkg`](extract/moon.pkg) —— 依赖与 `dev_build` 生成规则
