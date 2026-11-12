extends Node
## 国际化体检探针（headless，退出码 0 = 全过）。设计见 feature_design.md §二十六。
##
## 为什么需要它：本项目只有 `en` / `zh` 两列文案 + **一个**字体，
## 而加语种时的三类事故都**不会报错、只会安静地显示不对**：
##   ① CSV 加了列但忘了登记 `Game.language` / `project.godot` —— 语言下拉里没有它；
##   ② CSV 改了但 `.translation` 没重导 —— `tr()` 原样吐回 key，界面显示 `_TowerName_xxx`；
##   ③ 译文里用了字体没有的字形 —— 靠 `allow_system_fallback` 蹭操作系统字体，
##      本机看着正常，Steam Deck / 精简系统的玩家看到的是豆腐块。
##      （实测抓到过一条：`_TutorialGuide4` 的 `▶` U+25B6 主字体根本没有。）
##
## 跑法：
##   f:/Godot_v4.7.1-stable_win64.exe --headless --path machine-td \
##     res://scene/test/i18n_probe.tscn
##
## 只管"结构与可显示性"，不管译文质量 —— 翻得准不准得人看。

const CSV_PATH := "res://lang/language.csv"
const MAX_REPORT_MISSING := 12

var _fails: int = 0
## 跑过的检查组。2026-11-12 真踩过一次：编辑 `_ready` 时把 C9/C10 挤到了 `quit()` 后面，
## 探针照样打印 `@@ DONE fails=0` —— **"全绿"和"跑了"是两件事**，所以这里必须对账。
var _ran: Array[String] = []
const EXPECTED_CHECKS := ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"]
var _csvKeys: Array[String] = []
var _csvHeader: Array[String] = []
var _rows: Array = []


func _ok(cond: bool, label: String, detail := "") -> void:
	if cond:
		print("@@ PASS " + label)
	else:
		_fails += 1
		print("@@ FAIL " + label + "|" + detail)


func _ready() -> void:
	if not loadCsv():
		print("@@ FAIL C0 CSV unreadable")
		print("@@ DONE fails=%d" % (_fails + 1))
		get_tree().quit(1)
		return

	checkStructure()
	checkLocaleRegistry()
	checkPlaceholders()
	checkRuntimeTranslations()
	await checkFontChain()
	checkGlyphCoverage()
	checkRequiredScripts()
	checkLocaleDetection()
	await checkMenuTextFits()
	await checkLanguageDropdown()

	var skipped: Array = []
	for c in EXPECTED_CHECKS:
		if not _ran.has(c):
			skipped.append(c)
	_ok(skipped.is_empty(), "C11 every registered check actually ran",
			"skipped=%s ran=%s" % [str(skipped), str(_ran)])

	print("@@ DONE fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


# ───────────────────────────── C9 主菜单按钮放不放得下 ─────────────────────────────

## 装进真实场景量真实控件，而不是比字符数 × 字号 —— 四条理由都是实测出来的：
##  ① 按钮带图标，预算不是"列宽减点边距"那么算；`get_combined_minimum_size()`
##     已经把图标、stylebox 内边距、内部 spacing 全算进去了。
##  ② 主字体里一个汉字 39px、一个西里尔字母平均 ~20px，按字号估会把俄语算短一半。
##  ③ `welcome.tscn` 里**内嵌了 setting 面板**，而 `setting.gd:44` 在 `_ready()` 里
##     会 `set_locale(UserData.language)` —— locale 必须在 `add_child` **之后**设，
##     否则被它盖回去，五个语种量到的是同一份中文。
##  ④ 只 `set_locale` 不会让已布局的控件重算最小尺寸（绘制时会 `atr()` 换字，
##     但缓存的最小尺寸不动）→ 必须把 `text` 摘下再装回去才拿到新数字。
const MENU_COLUMN_PATH := "Ui/HBoxContainer"

func checkMenuTextFits() -> void:
	_ran.append("C9")
	var welcomePath := "res://scene/welcome.tscn"
	for code in localeColumns():
		if not FileAccess.file_exists("res://lang/language.%s.translation" % code):
			continue          # C2d 已经报过了，这里不重复刷
		var scene: PackedScene = load(welcomePath)
		if scene == null:
			_ok(false, "C9 %s: welcome.tscn 打不开" % code)
			continue
		var welcome: Node = scene.instantiate()
		add_child(welcome)
		await get_tree().process_frame
		TranslationServer.set_locale(code)
		var col: Control = welcome.get_node_or_null(MENU_COLUMN_PATH)
		if col == null:
			_ok(false, "C9 %s: 找不到 %s" % [code, MENU_COLUMN_PATH])
			remove_child(welcome); welcome.free()
			continue
		var over: Array = []
		var widths: Array = []
		for btn in col.get_children():
			if not (btn is Button):
				continue
			var key: String = (btn as Button).text
			if not key.begins_with("_"):
				continue
			(btn as Button).text = ""            # 逼它重算最小尺寸（见上面第 ④ 条）
			(btn as Button).text = key
			var need: float = (btn as Control).get_combined_minimum_size().x
			var got: float = (btn as Control).size.x
			var shown := TranslationServer.translate(key)
			widths.append("%s=%.0f" % [shown, need])
			if need > got + 0.5:
				over.append("%s 需要%.0f>可得%.0f" % [shown, need, got])
		_ok(over.is_empty(), "C9 %s main menu buttons fit (%.0f 列宽)" % [code, col.size.x],
				"%s | %s" % [str(over), " ".join(widths)])
		remove_child(welcome)
		welcome.free()
		await get_tree().process_frame


# ───────────────────────────── C10 语言下拉 ─────────────────────────────

## `setting.tscn:93` 那个 OptionButton 的 `custom_minimum_size = Vector2(240, 56)`
## 是**下限不是上限**（§26.6 早期把它当预算写错了，这里补一条实测把结论钉住）：
## 语种名再加长、下拉里再加几种语言，控件都会自己长大，父级是 968 宽的面板，不会被截断。
## 真正会截断的是**固定 offset 摆出来的容器**（见 C9 的主菜单列）。
func checkLanguageDropdown() -> void:
	_ran.append("C10")
	var setting: Node = (load("res://scene/setting.tscn") as PackedScene).instantiate()
	add_child(setting)
	await get_tree().process_frame
	var box: OptionButton = setting.get_node_or_null(
		"Box/VBoxContainer/languageBox/HBoxContainer/language") as OptionButton
	_ok(box != null, "C10a 找到语言下拉节点")
	if box != null:
		box.clear()
		for entry in Game.language:
			box.add_item(String(entry.get("text", "")))
		var grown: float = box.get_combined_minimum_size().x
		var avail: float = maxf(box.size.x, 240.0)
		# 需要宽度 <= 可用宽度。这里 240 是**下限**（custom_minimum_size），
		# 所以判据是"最坏内容是否还在下限之内"：还在，就不会截断；
		# 哪天某个语种名把它顶过 240（Русский 现在 163），这条就会红，提醒去加宽下拉。
		_ok(grown <= avail + 0.5, "C10b 语种名的最坏需求仍在下拉可用宽度内",
				"需要=%.0f 可用=%.0f" % [grown, avail])
		print("@@ INFO 下拉框：装满 %d 个语种名需要 %.0f，可用 %.0f（声明下限 240）"
			% [Game.language.size(), grown, avail])
	remove_child(setting)
	setting.free()
	await get_tree().process_frame


# ───────────────────────────── C8 系统语言判定 ─────────────────────────────

## `userData.gd::detectLanguageFromSystem()` 的判定表与 `Game.language` 对不对得上。
## 这里**不 stub `OS.get_locale()`**（OS 是引擎单例，桩不掉），
## 所以把规则抽成纯函数 `_languageFromLocaleString()` 来测各种 locale 输入。
## 专门盯两件事：① `zh_HK` / `zh_MO` 不能被当成简体；② 未知语种必须回 `en`
## （`Game.t()` 的兜底也是英文，两边不一致就会出现"判成 A、缺词回英文"的混排）。
func checkLocaleDetection() -> void:
	_ran.append("C8")
	var userData: Node = get_node_or_null("/root/UserData")
	_ok(userData != null and userData.has_method("detectLanguageFromSystem"),
		"C8a userData exposes detectLanguageFromSystem()")
	if userData == null:
		return
	var registered := {}
	for entry in Game.language:
		registered[String(entry.get("code", ""))] = true
	var cases := {
		"zh_CN": "zh", "zh_SG": "zh",
		"zh_TW": "zh_TW", "zh_HK": "zh_TW", "zh_MO": "zh_TW",
		"ja_JP": "ja", "ru_RU": "ru",
		"en_US": "en", "de_DE": "en", "fr_FR": "en", "ko_KR": "en",
	}
	var wrong: Array = []
	for locale in cases.keys():
		var want := String(cases[locale])
		# 未登记的语种期望回 en；如果哪天加了 ko 列，这条自动改成要求 ko
		if want == "en" and registered.has("ko") and locale == "ko_KR":
			want = "ko"
		# ⚠️ 必须显式声明类型：`var got := userData.call(...)` 是从 Variant 推断，
		#    本项目把警告当错误（§八 2026-11-05 记过一次），脚本会直接解析失败、探针静默不跑
		var got: String = String(userData.call("_languageFromLocaleString", locale))
		if got != want:
			wrong.append("%s -> %s (want %s)" % [locale, got, want])
	_ok(wrong.is_empty(), "C8b system locale maps to the right code (繁简优先序)", str(wrong))
	# 判定结果必须真的是登记过的语种，否则 set_locale 会切到一个没有译文的语言
	var orphan: Array = []
	for locale in cases.keys():
		var detected: String = String(userData.call("_languageFromLocaleString", locale))
		if not registered.has(detected):
			orphan.append("%s -> %s" % [locale, detected])
	_ok(orphan.is_empty(), "C8c every detected code is a registered language", str(orphan))


## 手工解析：引号包裹、`""` 转义。不能用 `split(",")` —— 文案里有逗号。
func loadCsv() -> bool:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var row: Array[String] = []
	var field := ""
	var inQuotes := false
	var i := 0
	while i < text.length():
		var ch := text[i]
		if inQuotes:
			if ch == "\"":
				if i + 1 < text.length() and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					inQuotes = false
			else:
				field += ch
		elif ch == "\"":
			inQuotes = true
		elif ch == ",":
			row.append(field)
			field = ""
		elif ch == "\r":
			pass
		elif ch == "\n":
			row.append(field)
			field = ""
			_rows.append(row)
			row = []
		else:
			field += ch
		i += 1
	if field != "" or not row.is_empty():
		row.append(field)
		_rows.append(row)
	if _rows.is_empty():
		return false
	_csvHeader = _rows[0]
	_rows.remove_at(0)
	for r in _rows:
		_csvKeys.append(r[0])
	return true


func localeColumns() -> Array[String]:
	var out: Array[String] = []
	for c in range(1, _csvHeader.size()):
		out.append(_csvHeader[c])
	return out


# ───────────────────────────── C1 结构 ─────────────────────────────

func checkStructure() -> void:
	_ran.append("C1")
	_ok(_csvHeader.size() >= 3, "C1a header has Keys + at least 2 locale columns",
			"header=%s" % str(_csvHeader))
	var badWidth := 0
	for r in _rows:
		if r.size() != _csvHeader.size():
			badWidth += 1
	_ok(badWidth == 0, "C1b every row has one cell per column", "bad=%d" % badWidth)
	var empties: Array = []
	var blankKeys := 0
	for r in _rows:
		if str(r[0]).strip_edges().is_empty():
			blankKeys += 1
			continue
		for c in range(1, r.size()):
			if str(r[c]).strip_edges().is_empty():
				empties.append("%s:%s" % [r[0], _csvHeader[c]])
	_ok(blankKeys == 0, "C1c no blank key rows", "count=%d" % blankKeys)
	_ok(empties.is_empty(), "C1d no empty translation cells",
			"%d cells, e.g. %s" % [empties.size(), str(empties.slice(0, 5))])
	var seen := {}
	var dupes: Array = []
	for k in _csvKeys:
		if seen.has(k):
			dupes.append(k)
		seen[k] = true
	_ok(dupes.is_empty(), "C1e no duplicate keys", str(dupes.slice(0, 5)))
	_ok(_csvKeys.size() >= 250, "C1f key count sane", "keys=%d" % _csvKeys.size())
	print("@@ INFO keys=%d locales=%s" % [_csvKeys.size(), str(localeColumns())])


# ───────────────────────────── C2 语种登记 ─────────────────────────────

func checkLocaleRegistry() -> void:
	_ran.append("C2")
	var declared: Array[String] = []
	for entry in Game.language:
		declared.append(str(entry["code"]))
	var columns := localeColumns()
	var missingInRegistry: Array = []
	for code in columns:
		if not declared.has(code):
			missingInRegistry.append(code)
	_ok(missingInRegistry.is_empty(), "C2a every CSV column is declared in Game.language",
			"orphan columns=%s declared=%s" % [str(missingInRegistry), str(declared)])
	var missingInCsv: Array = []
	for code in declared:
		if not columns.has(code):
			missingInCsv.append(code)
	_ok(missingInCsv.is_empty(), "C2b every declared language has a CSV column",
			"missing=%s" % str(missingInCsv))

	# project.godot 的 locale/translations 必须列出每个语种的编译产物
	var pf := FileAccess.open("res://project.godot", FileAccess.READ)
	var projectText := pf.get_as_text() if pf != null else ""
	var unlisted: Array = []
	for code in columns:
		var needle := "language.%s.translation" % code
		if not projectText.contains(needle):
			unlisted.append(needle)
	_ok(unlisted.is_empty(), "C2c project.godot locale/translations lists every column",
			str(unlisted))
	# 而且编译产物真的存在（CSV 改了没重导时会缺文件）
	var absent: Array = []
	for code in columns:
		if not FileAccess.file_exists("res://lang/language.%s.translation" % code):
			absent.append(code)
	_ok(absent.is_empty(), "C2d compiled .translation exists for every column", str(absent))


# ───────────────────────────── C3 占位符 ─────────────────────────────

func checkPlaceholders() -> void:
	_ran.append("C3")
	var re := RegEx.create_from_string("%[0-9*]*[dfs]")
	var mismatches: Array = []
	for r in _rows:
		var baseline: Array = []
		var firstName := ""
		for c in range(1, r.size()):
			var found: Array = []
			for m in re.search_all(str(r[c])):
				found.append(m.get_string())
			found.sort()
			if firstName == "":
				baseline = found
				firstName = _csvHeader[c]
			elif found != baseline:
				mismatches.append("%s %s!=%s %s vs %s" % [r[0], firstName,
						_csvHeader[c], str(baseline), str(found)])
	_ok(mismatches.is_empty(), "C3 format placeholders identical across locales",
			"%d rows, e.g. %s" % [mismatches.size(), str(mismatches.slice(0, 3))])


# ───────────────────────────── C4 运行时真的取得到 ─────────────────────────────

func checkRuntimeTranslations() -> void:
	_ran.append("C4")
	# 检测器自检：不存在的 key 必须**原样返回**，
	# 否则下面"翻译结果等于 key 就算缺"的判据是假的。
	# （4.7 的 TranslationServer 没有 has_key，只能这么判）
	_ok(TranslationServer.translate("_NoSuchKey_probe_zzz") == "_NoSuchKey_probe_zzz",
		"C4a unknown key passes through unchanged (detector is real)")
	var previous := TranslationServer.get_locale()
	for code in localeColumns():
		TranslationServer.set_locale(code)
		var col := _csvHeader.find(code)
		var unresolved: Array = []
		var stale: Array = []
		for r in _rows:
			var key := String(r[0])
			var got := TranslationServer.translate(key)
			if got == key:
				unresolved.append(key)
				continue
			# 与 CSV **逐条比对**：只查 key 在不在，抓不到"改了 CSV 但没重新导入"——
			# 旧的 .translation 里 key 也在，只是文案是旧的。
			var expect := unescapeCsv(String(r[col]))
			if got != expect:
				stale.append("%s csv=%s runtime=%s" % [key, expect.left(28), got.left(28)])
		_ok(unresolved.is_empty(), "C4b locale %s resolves every CSV key" % code,
				"%d missing, e.g. %s —— CSV 改了但没跑 --import？"
					% [unresolved.size(), str(unresolved.slice(0, 4))])
		_ok(stale.is_empty(), "C4c locale %s runtime text still matches CSV" % code,
				"%d differ, e.g. %s" % [stale.size(), str(stale.slice(0, 4))])
	TranslationServer.set_locale(previous)


## Godot 的 CSV 导入器开了 `unescape_translations=true`（见 `lang/language.csv.import`），
## 所以 `\n` 这类转义在运行时已经是真换行。比对前先手工还原同样的转义，
## 否则带 `\n` 的长文案（`_About_Text`）会被误报成"CSV 与运行时不一致"。
func unescapeCsv(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and i + 1 < text.length():
			var nxt := text[i + 1]
			if nxt == "n":
				out += "\n"
			elif nxt == "t":
				out += "\t"
			elif nxt == "\"":
				out += "\""
			else:
				out += ch
				out += nxt
			i += 2
			continue
		out += ch
		i += 1
	return out


# ───────────────────────────── C5 字体链装配 ─────────────────────────────

func checkFontChain() -> void:
	_ran.append("C5")
	var stack: Node = get_node_or_null("/root/FontStack")
	_ok(stack != null, "C5a FontStack autoload present")
	if stack == null:
		return
	await get_tree().process_frame
	var chain: Array = stack.fontChain()
	_ok(chain.size() >= 1, "C5b chain has the base font", "size=%d" % chain.size())
	var dirCount: int = (stack.discoverFallbackPaths() as Array).size()
	_ok(chain.size() == 1 + dirCount, "C5c chain == base + every file in font/fallback/",
			"chain=%d dir=%d" % [chain.size(), dirCount])
	var main: Font = chain[0] if not chain.is_empty() else null
	_ok(main != null and main.has_char(0x4E2D), "C5d base font renders CJK")
	# 反向自检：私用区永远不该有字形 —— 若这里返回真，说明 has_char 不能信
	_ok(main != null and not main.has_char(0xE000),
		"C5e detector sanity (private-use codepoint must be missing)")
	print("@@ INFO fallbacks=%s" % str(stack.loadedFonts))

	# C5f **合并而不是覆盖**：链上已经有"别人配的"字体时，再跑一次 apply() 不许把它抹掉。
	# （早期版本这里是直接赋值，症状是"编辑器里配好了、进游戏仍然缺字"，只在运行时出现）
	# ⚠️ 哨兵必须是**与主字体无引用关系**的 Font：拿 `FontVariation(base_font = 主字体)`
	#    塞进主字体自己的 `fallbacks` 会构成 **主字体 → 回退 → 变体 → 主字体** 的环，
	#    后面的字形查询直接把这个进程问崩（实测踩过）。空 `FontFile` 才是安全的哨兵。
	if main is FontFile:
		var sentinel := FontFile.new()
		var before: Array = (main as FontFile).fallbacks.duplicate()
		(main as FontFile).fallbacks.append(sentinel)
		stack.apply()
		var after: Array = (main as FontFile).fallbacks
		_ok(after.has(sentinel), "C5f apply() keeps fallbacks configured elsewhere",
				"after=%d before=%d" % [after.size(), before.size()])
		_ok(after.size() == 1 + dirCount, "C5g merge adds the directory fonts without duplicating",
				"after=%d dir=%d" % [after.size(), dirCount])
		# 还原：把哨兵摘掉再重跑一次，别把临时对象留在链上
		(main as FontFile).fallbacks = before
		stack.apply()


# ───────────────────────────── C6 字形覆盖 ─────────────────────────────

func checkGlyphCoverage() -> void:
	_ran.append("C6")
	var stack: Node = get_node_or_null("/root/FontStack")
	if stack == null:
		_ok(false, "C6 skipped: no FontStack to ask about glyphs")
		return
	# 逐语种统计"译文里用到、但整条链都画不出"的码位
	for code in localeColumns():
		var col := _csvHeader.find(code)
		var missing := {}
		var samples := {}
		var checked := 0
		for r in _rows:
			if col <= 0 or col >= r.size():
				continue
			for ch in String(r[col]):
				var cp := ch.unicode_at(0)
				if cp < 0x20 or cp == 0x20:
					continue
				checked += 1
				if not stack.hasGlyphAcrossChain(cp):
					missing[cp] = int(missing.get(cp, 0)) + 1
					if not samples.has(cp):
						samples[cp] = String(r[0])
		var lines: Array = []
		for cp in missing.keys():
			lines.append("U+%04X x%d in %s" % [cp, missing[cp], samples[cp]])
		_ok(missing.is_empty(), "C6 locale %s has no unrenderable glyph" % code,
				"%d chars checked; missing: %s" % [checked, str(lines.slice(0, MAX_REPORT_MISSING))])
		if not missing.is_empty():
			print("@@ HINT %s 缺字形清单：%s" % [code, " | ".join(lines)])


## C7 语种 ↔ 文字系统：声明了某个语言，链里就必须**有能力**画它的文字。
##
## 为什么单独一条：C6 只查"现有译文里用到了哪些字"，
## 而加语种时最常见的事故顺序是**先登记语言、后补字体、文案还没翻** ——
## 那一刻 CSV 里可能一条该语种的文字都还没有，C6 全绿，
## 但下拉里已经出现「한국어」，玩家切过去看到的仍然是豆腐块。
## 这条按语言 code 查一个**代表性码位**，把顺序问题当场抓住。
const SCRIPT_PROBES := {
	"en": [0x0041, 0x007A],              # 基础 Latin
	"ja": [0x3042, 0x30AB, 0x4E2D],      # 平假名 / 片假名 / 汉字
	"ko": [0xAC00, 0xD55C, 0x3131],      # 谚文音节 / Jamo
	"th": [0x0E01, 0x0E31, 0x0E32],      # 辅音 / 上置元音 / 声调位
	"zh": [0x4E2D, 0x8A9E, 0x3001],      # 汉字（含繁体的「語」）/ 顿号
	"ru": [0x0410, 0x044F],              # 西里尔大小写
	"ar": [0x0627],                      # 阿拉伯文
	"vi": [0x01B0, 0x1ED9],              # ư / ộ（Latin Extended Additional）
	"el": [0x0391],                      # 希腊文
	"he": [0x05D0],
}

func checkRequiredScripts() -> void:
	_ran.append("C7")
	var stack: Node = get_node_or_null("/root/FontStack")
	if stack == null:
		return
	for code in localeColumns():
		var probes := probesForLocale(code)
		if probes.is_empty():
			print("@@ INFO %s 没有对应的文字探针（未知语种）" % code)
			continue
		var gaps: Array = []
		for cp in probes:
			if not stack.hasGlyphAcrossChain(cp):
				gaps.append("U+%04X" % cp)
		_ok(gaps.is_empty(), "C7 locale %s can render its own script" % code,
				"missing %s —— 往 font/fallback/ 放对应字体（见该目录 README）" % str(gaps))


## `zh_TW` / `zh_Hant` / `pt_BR` 这类带地区或文字后缀的 code，按前缀与别名匹配
func probesForLocale(code: String) -> Array:
	var lower := code.to_lower()
	for key in SCRIPT_PROBES:
		if lower == key or lower.begins_with(key + "_") or lower.begins_with(key + "-"):
			return SCRIPT_PROBES[key]
	return []
