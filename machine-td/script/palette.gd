class_name Palette
## 全工程唯一的 UI / 世界配色来源（art_style.md §3）。
##
## 为什么要收口成一张表：同一个安全黄此前在脚本里有 4 种写法
## （`Color(1, 0.7764706, 0.101960786)` / `Color(1.0, 0.776, 0.102)` /
## `Color(1, 0.776471, 0.101961)` / `Color("ffc61a")`），另外还有十几个
## "近似但不是"的漂移色（`#FFC7B8` vs `danger_text #FFB3A0`、
## `#A8AFA8` vs `ui_300 #9FB4C4`）。写法散 → 改色要全工程搜，
## 而且做不了 art_style.md §12.5 那种"同几何换色"。
##
## 规矩：
##   · UI 脚本里的颜色**只能**从这里取，带透明度用 `Color(Palette.UI_600, 0.98)`
##     （Godot 4 已移除 `Color.with_alpha()`，别写）；
##   · `theme/**/*.tres` 是资源文件，引用不了脚本常量，保持字面量，
##     由 `.td_verify/theme_check.gd` 反查这些 token 保证两边不打架；
##   · **特效色不进这张表**（特斯拉电弧、EMP 雷达、Boss 光环、残骸、飘字粒子
##     等按各自素材定，见 §13.6 的说明），免得把"美术自由度"锁死在 UI 色板上。

# ── 金属阶梯（§3.2，UI 骨架）──
const UI_950 := Color("#1a1c2c")   # 凹陷槽 / 轨道 / 按下 / 描边
const UI_800 := Color("#333c57")   # 按钮常态 / 小标签 / **地板主色**
const UI_850 := Color("#262c42")   # 禁用按钮底（v8.5e，比常态再深一档）
const UI_700 := Color("#38435e")   # **面板底**（v8.5e 起，原 ui_600）
const UI_750 := Color("#44586e")   # 历史按钮常态（v8.5e 起按钮用 UI_800）
const UI_720 := Color("#4a5f78")   # 小标签边框
const UI_600 := Color("#566c86")   # 卡片底 / 悬停前的抬升档（v8.5e 起按钮常态用 UI_800）
const UI_500 := Color("#6f8aa4")   # 按钮悬停
const UI_450 := Color("#7f96a8")   # 分隔线 / 滚动条抓手
const UI_400 := Color("#94b0c2")   # 面板 2px 亮边框
const UI_300 := Color("#9fb4c4")   # 压暗文字（禁用）
const UI_100 := Color("#dceaf2")   # 次要文字
const UI_050 := Color("#f8fbfd")   # 主文字
const UI_000 := Color("#f4f4f4")   # 最亮（悬停 / 按下文字）

# ── 主强调 · 安全黄（§3.3，只给"我方 / 选中 / 可操作 / 关键数值"）──
const HAZARD_900 := Color("#3e361a")   # 深金槽：选中态底衬（原 codex_panel 写死）
const HAZARD_700 := Color("#8a6a00")
const HAZARD_600 := Color("#c99700")
const HAZARD_500 := Color("#ffc61a")
const HAZARD_300 := Color("#ffd964")

# ── 语义色（§3.4）──
const DANGER := Color("#a95035")
const DANGER_TEXT := Color("#ffb3a0")
const DANGER_DEEP := Color("#6b241a")   # 危险底衬（原 title.gd / level_intro_panel.gd 各自写死）
const WARN := Color("#e08a2e")
const SUCCESS := Color("#4aa222")
const SUCCESS_LT := Color("#a7f070")
const INFO := Color("#48b2a8")
const INFO_LT := Color("#7fd0c6")
const GEM := Color("#6fd6ea")

# ── 语义动作色（塔操作按钮 / 血条填充，theme/style 里的字面量必须等于这些 token）──
const REPAIR_BG := Color("#1f4a39")
const REPAIR_BORDER := Color("#4bbc83")
const REPAIR_BG_HOVER := Color("#2d6850")
const REPAIR_BORDER_HOVER := Color("#6de6a0")
const SELL_BG := Color("#613f1d")
const SELL_BORDER := Color("#f2ad3e")
const SELL_BG_HOVER := Color("#7c5525")
const SELL_BORDER_HOVER := Color("#ffdc7a")
const HP_FILL := Color("#d95a3c")

# ── 警报暖阶（Boss / 敌方压迫感）──
# 收编原先散在 boss_health_row / boss_bar_ticks / early_call_panel 里的
# #F2994C / #FFD18C / #FF9E52 / #FF9E6B / #FF5940 / #FF6B52 六个写法。
# 为什么不并进安全黄：黄 = 我方（§6 铁律），橙 = 敌方压迫，两者不能同义。
const ALERT_500 := Color("#f2994c")
const ALERT_300 := Color("#ffd18c")
const ALERT_HOT := Color("#ff5940")

# ── 结构色（§13.7 步骤 2：面板外缘深色收边）──
const RIM := Color("#0d1016")           # 面板最外圈深色收边 / 阴影
const FLOOR := UI_800                   # 车间地面 = 清屏色，语义别名

# 校验用：`.td_verify/theme_check.gd` 拿这张表反查场景与 StyleBox 里的颜色
const REGISTERED := {
	"UI_950": UI_950, "UI_850": UI_850, "UI_800": UI_800, "UI_700": UI_700, "UI_750": UI_750, "UI_720": UI_720,
	"UI_600": UI_600, "UI_500": UI_500, "UI_450": UI_450, "UI_400": UI_400,
	"UI_300": UI_300, "UI_100": UI_100, "UI_050": UI_050, "UI_000": UI_000,
	"HAZARD_900": HAZARD_900, "HAZARD_700": HAZARD_700, "HAZARD_600": HAZARD_600,
	"HAZARD_500": HAZARD_500, "HAZARD_300": HAZARD_300,
	"DANGER": DANGER, "DANGER_TEXT": DANGER_TEXT, "DANGER_DEEP": DANGER_DEEP,
	"WARN": WARN, "SUCCESS": SUCCESS, "SUCCESS_LT": SUCCESS_LT,
	"INFO": INFO, "INFO_LT": INFO_LT, "GEM": GEM,
	"REPAIR_BG": REPAIR_BG, "REPAIR_BORDER": REPAIR_BORDER,
	"REPAIR_BG_HOVER": REPAIR_BG_HOVER, "REPAIR_BORDER_HOVER": REPAIR_BORDER_HOVER,
	"SELL_BG": SELL_BG, "SELL_BORDER": SELL_BORDER,
	"SELL_BG_HOVER": SELL_BG_HOVER, "SELL_BORDER_HOVER": SELL_BORDER_HOVER,
	"HP_FILL": HP_FILL,
	"ALERT_500": ALERT_500, "ALERT_300": ALERT_300, "ALERT_HOT": ALERT_HOT,
	"RIM": RIM,
}


## 找到与 c 最接近的 token 名；供校验脚本报告"这个色该归到哪个 token"。
static func nearest(c: Color) -> String:
	var best := ""
	var best_d := 9.9
	for k in REGISTERED:
		var t: Color = REGISTERED[k]
		var d := maxf(maxf(absf(c.r - t.r), absf(c.g - t.g)), absf(c.b - t.b))
		if d < best_d:
			best_d = d
			best = k
	return "%s(偏差 %.3f)" % [best, best_d]
