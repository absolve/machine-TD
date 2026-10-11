extends "res://script/ui/battle_start_banner.gd"
## 波次来袭横幅：每一波开始时闪一下「第 N 波」，下面列出这一波会出现的敌人。
##
## ★ 继承 battle_start_banner.gd（见 code_design.md §6.2「基础脚本 + 子类只覆盖差异」）：
##   淡入 / 停留 / 淡出 / 缩放这套动画、`skip()`、`finished` 信号全部沿用父类，
##   本脚本**只加**"把敌人清单排出来"这一步。场景结构（center/band/content/VBox）
##   也与父场景一致，所以父类的 @onready 路径直接可用。
##
## 用法：
##     waveBanner.playWave(3, [{"name": "迷你坦克", "number": 22}, ...])
##     waveBanner.playWave(8, rows, true)   # 最后一波，标题换成「最后一波」

## 清单里每个兵种之间显示的分隔符。放在代码里而不是 .tscn —— 它不属于静态属性。
const SEPARATOR := "    "

@onready var enemyList: HBoxContainer = $center/band/content/VBox/enemyList
## 父类 _ready() 会把 subLabel 设成「敌人即将到来」。波次横幅里**不要这一行**：
## 标题已经写明是第几波、下面紧接着就是兵种清单，再来一句泛泛的副标题只是占地方。
## 只是把它藏起来（而不是删节点）—— 父类的 play() 仍会往它写文字，
## 保留节点可以让父类逻辑原样不动，子类只覆盖"这一行不显示"。
@onready var subLabelHidden: Label = $center/band/content/VBox/subLabel


## 播一遍本波横幅。
##
## ⚠️ 方法名**不能叫 `play`**：父类已经有 `play(title, sub, hold_override)`，
##    GDScript 不允许子类用不同签名覆盖它（报 "The function signature doesn't match
##    the parent"）。所以这里另起名 `playWave`，内部再调父类的 `play()` 播动画。
##
## `wave`       波次号（从 1 开始）
## `enemies`    [{ "name": 显示名, "number": 数量 }, ...]，**已按数量降序排好**
## `is_final`  最后一波：标题换成「最后一波」，比"第 8 波"更有紧迫感
func playWave(wave: int, enemies: Array = [], is_final: bool = false) -> void:
	var title: String = Game.t("_FinalWave", "Final Wave") if is_final \
		else Game.t("_WaveBannerFmt", "Wave %d") % wave
	# 隐藏父类那行「敌人即将到来」：见 subLabelHidden 的注释。
	# 放在 super.play() **之前** —— 父类的 play() 只在传了非空 sub 时才改它，
	# 但 _ready() 已经写过一次默认文案，所以这里要主动清掉。
	if subLabelHidden != null:
		subLabelHidden.text = ""
		subLabelHidden.visible = false
	buildEnemyList(enemies)
	# 交给父类播动画。清单已经写进 Label 里了，所以 sub 传空。
	# 最后一波稍停久一点（+0.6s），让玩家看清编制再开打。
	super.play(title, "", -1.0 if not is_final else holdSec + 0.6)


## 把敌人清单排版出来：名 + 「xN」。
##
## 为什么是"名"与"xN"分开两个 Label，而不是一个 "名 xN" 字符串 ——
## 分开之后数字可以用另一档字号/颜色强调，扫一眼就能看出哪个兵种多。
func buildEnemyList(enemies: Array) -> void:
	if enemyList == null:
		return
	for c in enemyList.get_children():
		c.queue_free()
	if enemies.is_empty():
		# 没拿到编制数据时不要留一条空白横带，直接不显示这一行
		enemyList.visible = false
		return
	enemyList.visible = true
	var first: bool = true
	for e in enemies:
		if not first:
			enemyList.add_child(makeSeparator())
		first = false
		enemyList.add_child(makeText(str(e.get("name", "?")), false))
		enemyList.add_child(makeText("x%d" % int(e.get("number", 0)), true))


func makeText(s: String, strong: bool) -> Label:
	var lbl := Label.new()
	lbl.text = s
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 数值档（金黄、略大）与名字档（浅色）分开，一眼看出哪个兵种多
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.776, 0.102) if strong else Color(0.898, 0.929, 0.961))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_font_size_override("font_size", 40 if strong else 36)
	return lbl


func makeSeparator() -> Label:
	var lbl := Label.new()
	lbl.text = SEPARATOR
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	lbl.add_theme_font_size_override("font_size", 36)
	return lbl
