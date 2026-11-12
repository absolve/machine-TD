extends Node
## 字体回退链装配（设计见 feature_design.md §二十六）。
##
## **要解决的问题**：全项目只有 `AlibabaPuHuiTi-3-85-Bold.ttf` 一个字体，
## 实测它覆盖 CJK 100%、假名 184/192，但**谚文 0/11172、泰文 0/128、
## 越南语变音符 4/256**。而 `.ttf.import` 里 `allow_system_fallback=true`
## 意味着缺字现在靠**操作系统**兜底 —— 本机看着正常，Steam Deck / 精简系统的
## 玩家就是满屏豆腐块。上架不能赌玩家机器上有什么字体。
##
## **这里做的事**：启动时把 `res://font/fallback/` 目录里的字体按文件名顺序
## 装成主字体的 `fallbacks` 链。装配点选在代码里而不是 `.import` 的
## `fallbacks=[]` 字段，有两个原因（§26.3）：
##   1. `.import` 的回退表要**逐个字体文件填引用**，而主字体被 23 个场景共用 ——
##      链只该配一次，配在资源上会让"加一个语种"变成"改一次 import 再重导全项目"。
##   2. 放进目录就生效 = 加语种的人只需要扔文件进去，不需要懂 Godot 导入系统。
## 主字体资源是**全局共享**的（没有 `resource_local_to_scene`），
## 所以改它的 `fallbacks` 一处生效，23 个场景不用动。
##
## ⚠️ **顺序 = 优先级**：Godot 取第一个能画出该字形的字体。
##    用文件名前缀控制（`01_`、`02_`…），不要用随机字母顺序 ——
##    同一个码位（比如 `・`）在 JP 和 KR 字体里都有时，先命中的那个决定字形风格。
##
## ⚠️ 本节点**只装链、不下载字体**。字体文件必须自己放进去（OFL 授权的
##    Noto 系列可以直接商用，§26.4 给了清单）。目录空的时候这里什么都不做，
##    行为与现在完全一致 —— 这条改动本身不会让任何现有文字发生变化。
##
## 加语种时往 `res://font/fallback/` 放（文件名前缀就是优先级）：
##   01_NotoSansKR.otf        谚文（主字体实测 0/11172）
##   02_NotoSansThai.ttf      泰文（主字体实测 0/128）
##   03_NotoSansJP.otf        补 `・`(U+30FB) 与 `々`(U+3005)
##   04_NotoSans-Regular.ttf  越南语变音符（主字体 Latin Ext-Add 只有 4/256）
## 放完跑一次 `--headless --import`（新资源要生成 .import），
## 再跑 `res://scene/test/i18n_probe.tscn` 看字形覆盖是不是真的绿了。
##
## （`export_presets.cfg:13` 的 `exclude_filter` 把 `scene/test/*`、`script/test/*`
##  挡在包里 —— 所以这套装配必须在**运行时**成立，不能只在探针里成立。）

## 主字体：`theme/theme.tres` 的 `default_font` 指向的就是它
const BASE_FONT_PATH := "res://font/AlibabaPuHuiTi-3-85-Bold.ttf"
## 回退字体投放目录：**扔进去就生效**，文件名前缀决定优先级
const FALLBACK_DIR := "res://font/fallback"
const FONT_EXTENSIONS := [".ttf", ".otf", ".woff", ".woff2"]

## 装配结果（探针 `i18n_probe` 会读这些值，确认链真的建起来了）
var loadedFonts: Array[String] = []
var baseFont: FontFile = null
## 本次 apply 从链上**保留下来**的既有回退（不是本目录提供的）——
## 来自 `.ttf.import` 的 Fallbacks，或主题引用层（`FontVariation.fallbacks`）配好的链。
## 探针 C5f 就是拿这个字段锁"合并而不是覆盖"这条语义的。
var inheritedFallbacks: Array[Font] = []


func _ready() -> void:
	apply()


## 把 `FALLBACK_DIR` 里的字体装进主字体的回退链。幂等：可以重复调（切语种不需要重跑）。
##
## ⚠️ **是合并，不是覆盖**（2026-11-12 实测后改的）。
##    回退链有三个可配点：`.ttf.import` 的 Fallbacks、主题引用层
##    （`FontFile` 与 `FontVariation` 都带 `fallbacks` 属性）、以及这里的目录装配。
##    早期版本这里是 `baseFont.fallbacks = 目录扫到的链`，
##    等于**每次启动把别人在导入设置里配好的链抹掉** ——
##    症状是"编辑器里明明配了，进游戏仍然缺字"，而且只在运行时出现，很难查。
##    现在：继承来的排前面（保持它的优先级语义），目录里的追加在后，同一实体不重复入链。
func apply() -> void:
	baseFont = load(BASE_FONT_PATH) as FontFile
	if baseFont == null:
		push_warning("fontStack: 主字体加载失败 %s" % BASE_FONT_PATH)
		return

	var dirFonts: Array[Font] = []
	var dirPaths: Array[String] = []
	for path in discoverFallbackPaths():
		if path == BASE_FONT_PATH:
			continue
		var font: Font = load(path) as Font
		if font == null:
			# 放进来但加载不了（损坏 / 格式不支持）必须吵一句：
			# 否则链会**静默少一层**，缺字照样掉给系统兜底，而探针看着是绿的
			push_warning("fontStack: 回退字体加载失败 %s" % path)
			continue
		dirFonts.append(font)
		dirPaths.append(path)

	# 继承来的 = 现在挂在链上、但**不是**我们上次放进去的那些
	# （第一次 apply 时"上次"为空集，所以等于全量继承）
	var chain: Array[Font] = []
	for pre in baseFont.fallbacks:
		if pre == null or dirFonts.has(pre):
			continue
		if not chain.has(pre):
			chain.append(pre)
	inheritedFallbacks = chain.duplicate()

	loadedFonts.clear()
	for i in dirFonts.size():
		if chain.has(dirFonts[i]):
			continue          # 同一实体被导入设置和本目录各指一次：不重复入链
		chain.append(dirFonts[i])
		loadedFonts.append(dirPaths[i])

	baseFont.fallbacks = chain
	print("fontStack: 继承 %d 个 + 目录 %d 个 -> 链长 %d  %s"
		% [inheritedFallbacks.size(), loadedFonts.size(), chain.size(), str(loadedFonts)])


## 目录里的字体文件，**按文件名排序**（前缀 `01_/02_` 就是优先级）。
## 目录不存在就返回空表 —— 这是"还没放字体"的正常状态，不是错误。
func discoverFallbackPaths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(FALLBACK_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and matchesFontExtension(name):
			out.append(FALLBACK_DIR.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func matchesFontExtension(fileName: String) -> bool:
	var lower := fileName.to_lower()
	for ext in FONT_EXTENSIONS:
		if lower.ends_with(ext):
			return true
	return false


## 整条链（主字体 + 回退），探针按顺序查字形覆盖用它。
func fontChain() -> Array:
	var chain: Array = []
	if baseFont == null:
		return chain
	chain.append(baseFont)
	for font in baseFont.fallbacks:
		chain.append(font)
	return chain


## 这个码位在**整条链**里能不能画出来。
##
## 实测纠正（2026-11-12）：`Font.has_char()` **会顺着 `fallbacks` 往下找**
## —— 链清空时 `has_char(한)=false`，把韩文字体挂上就变 `true`；
## 而且关掉 `allow_system_fallback` 后，挂链的 `get_string_size("한국어")`
## 宽度从 **108.0 变成 120.0** —— 说明**真实排版**也在用回退字体，不只是查询接口。
## 这里仍然自己遍历，只剩一个理由：**报告是谁提供的这个字形**（探针打缺字清单要用），
## 不再是"因为 has_char 不查链"。
##
## ⚠️ 反过来有一条要知道：`has_char()` **不认系统兜底**。
##    开着 `allow_system_fallback` 时，缺字照样能被 OS 画出来（本机看着正常），
##    但 `has_char` 报 false —— 所以它恰好是"我们自己打进包的字体够不够"的正确问法。
func hasGlyphAcrossChain(codepoint: int) -> bool:
	for font in fontChain():
		if font != null and font.has_char(codepoint):
			return true
	return false


## 缺这个字形时该由链里哪个字体来补（探针报告用；返回空串表示整条链都补不上）。
func providerOf(codepoint: int) -> String:
	for i in range(fontChain().size()):
		var font: Font = fontChain()[i]
		if font != null and font.has_char(codepoint):
			return "chain[%d]" % i
	return ""
