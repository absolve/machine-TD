# font/fallback —— 字体回退链投放目录

**往这里扔字体文件就生效**，不用改代码、不用改 `.import`、不用改 23 个场景。

装配点是 `autoload/fontStack.gd`：启动时把本目录里的字体按**文件名排序**装进主字体
`AlibabaPuHuiTi-3-85-Bold.ttf` 的 `fallbacks` 链。Godot 取**第一个**能画出该字形的字体，
所以文件名前缀就是优先级 —— 同一个码位（比如 `・`）在 JP 与 KR 字体里都有时，
先命中的那个决定字形风格。

## 该放哪些（主字体覆盖率实测，2026-11-12）

| 建议文件名 | 服务的语言 | 主字体现状 |
|---|---|---|
| `01_NotoSansKR.otf` | 한국어 | 谚文音节 **0 / 11172** |
| `02_NotoSansThai.ttf` | ไทย | 泰文 **0 / 128**（辅音、上置元音、声调全缺） |
| `03_NotoSansJP.otf` | 日本語 | 假名 184/192，缺 `・` U+30FB 与 `々` U+3005 —— 日文 UI 高频 |
| `04_NotoSans-Regular.ttf` | Tiếng Việt | Latin Extended Additional **4 / 256**（`ư ộ ề ễ` 全缺） |

**已经满覆盖、不用加字体**：CJK 统一表意文字 20976/20992（所以繁体中文几乎零成本）、
西里尔字母（俄语免费）、希腊字母、基础 Latin。

## 步骤

1. 下载 **OFL（SIL Open Font License）** 授权字体，Noto 系列可自由商用：
   `github.com/notofonts/notofonts.github.io` 里按 `fonts/NotoSansKR/hinted/ttf/…` 取。
   ⚠️ **不要**从自己系统里抄 `Malgun Gothic` / `Leelawadee UI` —— 那是操作系统授权，
   不能随游戏分发，上架 Steam 是许可事故。
2. 按上表命名放进本目录（前缀编号 = 优先级）。
3. 跑一次 `--headless --import`（新资源必须生成 `.import`，否则 `load()` 拿不到）。
4. 跑探针验收：
   ```
   f:/Godot_v4.7.1-stable_win64.exe --headless --path machine-td \
     res://scene/test/i18n_probe.tscn
   ```
   `C5` 看链里有几个字体、`C6` 看每个语种还有没有画不出的字、`C7` 看语种声明的文字系统能不能画。

## ⚠️ 为什么必须自带字体

`AlibabaPuHuiTi-3-85-Bold.ttf.import:22` 的 `allow_system_fallback=true`，
意味着缺字目前**靠玩家的操作系统兜底**。本机（Windows）看着一切正常，
但 Steam Deck / Linux（fontconfig）或精简系统上就是满屏豆腐块 ——
而且这类问题在开发者机器上**永远复现不出来**。

## 另外两个"能配 fallback"的位置（2026-11-12 实测）

| 位置 | 行不行 | 为什么 |
|---|---|---|
| `Theme`（`theme/theme.tres`）上找 fallback | ❌ 没有这个东西 | Theme 只有**字体槽**：给 `Label` 换整支字体 ≠ 缺字时借字形。想"主题里配"，正确做法见下一行 |
| 主题引用一个 `FontVariation` .tres（`base_font` = 主字体，`fallbacks` = […]） | ✅ **推荐的第二条路** | `FontVariation` 也有 `fallbacks` 属性；`.tres` 进版本库、进导出包，纯声明式 |
| 主字体的 Import 面板 → Fallbacks（写进 `.ttf.import`） | ⚠️ 只在你本机有效 | 本仓库 `*.import` 被 gitignore（`git ls-files` 里 `.import` 计数为 0）。手写更不行：填路径串报 `String to Object`，补 `[ext_resource]` 报 `Resource file not found`，然后 Godot 重导时**把 `fallbacks` 重置回 `[]`** |

上面三条**互不覆盖**可以并存 —— `fontStack.gd` 的 `apply()` 是**合并**而不是覆盖，
所以你在编辑器里配好的链不会被启动时抹掉（`i18n_probe` 的 C5f/C5g 专门守这条）。

实测两条语义，免得下次又靠猜：
- `Font.has_char()` **会顺着 `fallbacks` 找**：链空 `has_char(한)=false`，挂上韩文字体即 `true`。
- 真实排版也走链：关掉 `allow_system_fallback` 后 `get_string_size("한국어")` **108.0 → 120.0**
  （36px 的豆腐块变成 40px 的真字形）。而**开着**系统兜底时不挂链也是 120.0 ——
  这就是"本机永远复现不出来"的那个坑。

## 为什么不配在 `.ttf.import` 的 `fallbacks` 字段

那是逐文件填引用，而主字体被 23 个场景共用；链只该配一次。
配在 import 上会让"加一个语种"变成"改一次 import + 重导全项目"。
另一个附带好处：探针能直接读 `FontStack.fontChain()` 验**运行时真实状态**，
而不是验一份"IDE 里配了、运行时没生效"的配置。
