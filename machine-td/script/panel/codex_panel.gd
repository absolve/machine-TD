extends Control
## 单位图鉴：把敌人和防御塔一格格铺成卡片网格，底下一条**固定**的信息栏。
##
## 交互
##   · 鼠标移到卡片 -> 信息栏临时显示它（只是预览，不改变选中）
##   · 左键点一下   -> 锁定为选中，鼠标移开信息栏也还留着它
##   · 切页签       -> 自动选中该页第一条
##   · 滚轮         -> 单位多的时候网格可滚动
##
## 分三层，互不依赖：
##   数据层  _enemy_entry / _tower_entry —— 把单位整理成统一的「条目字典」
##           （name / tag / desc / icon / color / stats），数值全部实时读 Game 的表
##   图标层  ENEMY_ICONS / TOWER_ICONS —— 就是两张「id -> 图片路径」的表，
##           想换图直接改路径，其余代码一概不用动
##   显示层  codex_card.tscn —— 卡片只认条目字典，完全不区分敌人还是塔
##
## 新增敌人 / 防御塔时只要进了 Game 的表（敌人还要进 StageData.enemyScenes），
## 图鉴自动多一张卡，这个脚本一行都不用改。
##
## 文案走 lang/language.csv：_Codex / _CodexEnemies / _CodexTowers / _CodexHoverHint。

signal closed ## 面板已关闭，宿主可以据此做后续处理

enum Tab { ENEMY, TOWER }

# ---------- 可调参数 ----------

## 网格每行几张卡
@export var columns := 6:
	set(value):
		columns = maxi(1, value)
		if is_node_ready() and grid != null:
			grid.columns = columns


# ---------- 样式常量 ----------

const COLOR_TEXT := Color(0.91764706, 0.9490196, 0.96862745, 1.0)
const COLOR_LABEL := Color(0.65882355, 0.6862745, 0.65882355, 1.0)
const COLOR_GOLD := Color(1, 0.7764706, 0.101960786, 1.0)
const COLOR_RED := Color(1, 0.5529412, 0.5019608, 1.0)      # 敌人主色：暖红
const COLOR_TEAL := Color(0.49803922, 0.8156863, 0.7764706, 1.0) # 防御塔主色：青
const COLOR_HOVER := Color(1, 0.8509804, 0.39215687, 1.0)

const STAT_WIDTH := 150 # 信息栏里每个数值块的最小宽度

## 敌人行为定位 -> 一句话说明（两边存的都是翻译键）
const ENEMY_DESC_KEYS := {
	"_EnemyRole_pusher": "_EnemyDesc_pusher",
	"_EnemyRole_attacker": "_EnemyDesc_attacker",
	"_EnemyRole_support": "_EnemyDesc_support",
	"_EnemyRole_bomber": "_EnemyDesc_bomber",
	"_EnemyRole_siege": "_EnemyDesc_siege",
	"_EnemyRole_air": "_EnemyDesc_air",
}

# ---------- 图片路径表 ----------
# 图鉴里每个单位显示哪张图，就写在这儿。**想换图直接改路径就行**，别的都不用动。
# 这些图是用 .td_verify/gen_unit_icons.gd 按游戏里的样子渲染出来的；
# 你也可以把它们换成项目里任意一张图。

const ENEMY_ICONS := {
	0: "res://sprite/icon/unit/miniTank.png",          # 迷你坦克
	1: "res://sprite/icon/unit/medium_tank.png",       # 中型坦克
	2: "res://sprite/icon/unit/heavy_tank.png",        # 重型坦克
	3: "res://sprite/icon/unit/armored_tank.png",      # 装甲坦克
	4: "res://sprite/icon/unit/assault_buggy.png",     # 突击车
	5: "res://sprite/icon/unit/medic.png",             # 维修车
	6: "res://sprite/icon/unit/suicide_truck.png",     # 自爆车
	7: "res://sprite/icon/unit/missile_truck.png",     # 导弹车
	8: "res://sprite/icon/unit/scout_drone.png",       # 侦察无人机
	9: "res://sprite/icon/unit/attack_helicopter.png", # 攻击直升机
}

# 防御塔同理。键是 Game.towerType 的枚举值，所以用 var 不用 const
# （Game 是自动加载单例，它的枚举值不是编译期常量）
var TOWERICONS: Dictionary = {
	Game.towerType.machineGunTower: "res://sprite/icon/unit/machineGunTower.png",
	Game.towerType.cannonTower: "res://sprite/icon/unit/cannonTower.png",
	Game.towerType.rocketTower: "res://sprite/icon/unit/rocketTower.png",
	Game.towerType.EMPTower: "res://sprite/icon/unit/EMPTower.png",
	Game.towerType.droneBase: "res://sprite/icon/unit/droneBase.png",
	Game.towerType.teslaCoilTower: "res://sprite/icon/unit/teslaCoilTower.png",
	Game.towerType.laserTower: "res://sprite/icon/unit/laserTower.png",
	Game.towerType.ironBox: "res://sprite/icon/unit/ironBox.png",
}

# ---------- 节点 ----------

@onready var titleLabel: Label = $Frame/PanelContainer/VBox/Header/Label
@onready var closeButton: Button = $Frame/PanelContainer/VBox/Footer/btnClose
@onready var tabEnemies: Button = $Frame/PanelContainer/VBox/Tabs/btnEnemies
@onready var tabTowers: Button = $Frame/PanelContainer/VBox/Tabs/btnTowers
@onready var grid: GridContainer = $Frame/PanelContainer/VBox/Scroll/CenterRow/grid
@onready var detailIcon: TextureRect = $Frame/PanelContainer/VBox/DetailBox/DetailVBox/DetailTop/IconCenter/detailIcon
@onready var detailName: Label = $Frame/PanelContainer/VBox/DetailBox/DetailVBox/DetailTop/DetailInfo/DetailHeader/detailName
@onready var detailTag: Label = $Frame/PanelContainer/VBox/DetailBox/DetailVBox/DetailTop/DetailInfo/DetailHeader/detailTag
@onready var detailDesc: Label = $Frame/PanelContainer/VBox/DetailBox/DetailVBox/DetailTop/DetailInfo/detailDesc
@onready var detailStats: GridContainer = $Frame/PanelContainer/VBox/DetailBox/DetailVBox/detailStats

# ---------- 状态 ----------

var _cardScene: PackedScene = preload("res://scene/codex_card.tscn")
var _tab: int = Tab.ENEMY
var _entries: Array = []      # 当前页签的条目（顺序 = Game 表里的声明顺序）
var _cards: Array = []        # 与 _entries 一一对应的卡片
var _selected: int = 0            # 锁定的条目下标；-1 = 该页没有单位
var _hover: int = -1              # 鼠标悬停的下标；-1 = 没悬停
var _sbNormal: StyleBoxFlat
var _sbHover: StyleBoxFlat
var _sbActive: StyleBoxFlat


func _ready() -> void:
	# 只接信号：内容等 open() -> refresh() 时再生成，
	# 不让人在欢迎界面就提前实例化十几个单位场景
	visible = false
	_buildCardStyles()
	grid.columns = columns
	tabEnemies.pressed.connect(_onTabPressed.bind(Tab.ENEMY))
	tabTowers.pressed.connect(_onTabPressed.bind(Tab.TOWER))


## 三种卡片外观：普通 / 鼠标悬停 / 已选中
func _buildCardStyles() -> void:
	_sbNormal = _makeCardStyle(Color(0.101960786, 0.12156863, 0.15686275, 0.85),
		Color(0.20392157, 0.23529412, 0.3019608, 1), 2)
	_sbHover = _makeCardStyle(Color(0.16078432, 0.19215687, 0.23921569, 0.95),
		Color(0.65882355, 0.6862745, 0.65882355, 1), 2)
	_sbActive = _makeCardStyle(Color(0.24313726, 0.21176471, 0.101960786, 0.95), COLOR_GOLD, 3)


func _makeCardStyle(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	return sb


# ---------- 开关 ----------

## 打开面板（每次打开都刷新一遍，保证数值和语言都是最新的）
func open() -> void:
	refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _onTabPressed(tab: int) -> void:
	if _tab == tab:
		return
	_tab = tab
	refresh()


# ---------- 页面 ----------

## 重建当前页签；打开面板 / 切页签都走这里
func refresh() -> void:
	_applyTexts()
	_styleTab(tabEnemies, _tab == Tab.ENEMY)
	_styleTab(tabTowers, _tab == Tab.TOWER)

	_clearChildren(grid)
	_entries = _collectEntries()
	_cards.clear()
	for i in _entries.size():
		_cards.append(_makeCard(_entries[i], i))

	# 切页签后默认选中第一条（没有单位就置 -1，信息栏显示提示语）
	_selected = 0 if not _entries.is_empty() else -1
	_hover = -1
	_syncCards()
	_updateDetail()


func _applyTexts() -> void:
	titleLabel.text = Game.t("_Codex", "Codex")
	closeButton.text = Game.t("_Close", "Close")
	# 页签带上条目数，新增敌人 / 塔时会自己变
	tabEnemies.text = "%s  %d" % [Game.t("_CodexEnemies", "Enemies"), Game.enemyInfo.size()]
	tabTowers.text = "%s  %d" % [Game.t("_CodexTowers", "Towers"), Game.towerInfo.size()]


func _styleTab(button: Button, active: bool) -> void:
	var base: Color = COLOR_GOLD if active else COLOR_TEXT
	button.add_theme_color_override("font_color", base)
	button.add_theme_color_override("font_focus_color", base)
	button.add_theme_color_override("font_pressed_color", COLOR_HOVER)
	button.add_theme_color_override("font_hover_color", COLOR_HOVER)
	button.modulate = Color(1, 1, 1, 1) if active else Color(0.82, 0.87, 0.92, 0.8)


# ---------- 卡片网格 ----------

func _makeCard(entry: Dictionary, index: int) -> Control:
	var card: Control = _cardScene.instantiate()
	# ★ 必须先入树再 setup —— 卡片的 @onready icon 要入树后才生效，
	#   反过来调 setup 的话 set_icon 会因为 icon 还是 null 而静默跳过（卡面全空）
	grid.add_child(card)
	card.setup(entry, _sbNormal, _sbHover, _sbActive)
	card.picked.connect(_onCardPicked.bind(index))
	card.hovered.connect(_onCardHovered.bind(index))
	card.unhovered.connect(_onCardUnhovered.bind(index))
	return card


## 点一下 = 锁定选中
func _onCardPicked(_entry: Dictionary, index: int) -> void:
	if _selected == index:
		return
	_selected = index
	_syncCards()
	_updateDetail()


## 悬停 = 临时预览（不动选中项）
func _onCardHovered(_entry: Dictionary, index: int) -> void:
	if _hover == index:
		return
	_hover = index
	_updateDetail()


func _onCardUnhovered(index: int) -> void:
	if _hover != index:
		return
	_hover = -1
	_updateDetail()


## 只同步「选中」标记；悬停外观由卡片自己的 mouse_entered 处理，
## 这样悬停预览时不会把金色的选中框也带走
func _syncCards() -> void:
	for i in _cards.size():
		var card: Control = _cards[i]
		if card == null or not is_instance_valid(card):
			continue
		card.setSelected(i == _selected)


# ---------- 信息栏（固定在底部） ----------

## 悬停优先，其次选中；两者都没有就回到提示语。
## 有选中项时信息栏**永远有内容**，不会因为鼠标移开就空掉。
func _updateDetail() -> void:
	_syncCards()
	var index: int = _hover if _hover >= 0 else _selected
	if index < 0 or index >= _entries.size():
		_showHint()
		return
	_showDetail(_entries[index])


func _showDetail(entry: Dictionary) -> void:
	detailIcon.texture = entry["icon"]
	detailName.text = entry["name"]
	detailName.modulate = COLOR_TEXT
	detailTag.text = entry["tag"]
	detailTag.modulate = entry["color"]
	detailDesc.text = entry["desc"]

	_clearChildren(detailStats)
	detailStats.columns = int(entry["stat_columns"])
	for stat in entry["stats"]:
		_addStat(str(stat[0]), str(stat[1]), stat[2])


func _showHint() -> void:
	detailIcon.texture = null
	detailName.text = Game.t("_CodexHoverHint", "Pick a unit to see its details")
	detailName.modulate = COLOR_LABEL
	detailTag.text = ""
	detailDesc.text = ""
	_clearChildren(detailStats)


## 一个数值块：小标题 + 大数值
func _addStat(title: String, value: String, color: Color) -> void:
	var chip: VBoxContainer = VBoxContainer.new()
	chip.custom_minimum_size = Vector2(STAT_WIDTH, 0)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_makeLabel(title, 22, COLOR_LABEL))
	chip.add_child(_makeLabel(value, 32, color))
	detailStats.add_child(chip)


func _makeLabel(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------- 数据层：唯一需要区分敌人 / 塔的地方 ----------

func _collectEntries() -> Array:
	var out: Array = []
	if _tab == Tab.ENEMY:
		for id in Game.enemyInfo:
			out.append(_enemyEntry(id))
	else:
		for id in Game.towerInfo:
			out.append(_towerEntry(id))
	return out


## 条目格式（显示层只认这几个 key）：name / tag / desc / icon / color / stat_columns / stats
func _enemyEntry(id: int) -> Dictionary:
	var info: Dictionary = Game.enemyInfo.get(id, {})
	var atk: int = int(info.get("atk", 0))
	var delay: float = float(info.get("shootDelay", 0.0))
	return {
		"name": Game.getEnemyDisplayName(id),
		"tag": Game.getEnemyRoleName(id),
		"desc": Game.t(str(ENEMY_DESC_KEYS.get(str(info.get("role", "")), "")), ""),
		"icon": _icon(ENEMY_ICONS, id),
		"color": COLOR_RED,
		"stat_columns": 6, # 11 项数值排两行
		"stats": [
			[Game.t("_HP", "HP"), str(int(info.get("hp", 0))), COLOR_RED],
			[Game.t("_Speed", "Speed"), str(int(info.get("speed", 0))), COLOR_TEXT],
			[Game.t("_Armor", "Armor"), "%d%%" % roundi(float(info.get("armor", 0.0)) * 100.0), COLOR_TEXT],
			[Game.t("_Flying", "Flying"), _yesNo(bool(info.get("flying", false))), COLOR_TEXT],
			[Game.t("_Atk", "ATK"), _positive(atk), COLOR_TEXT],
			[Game.t("_FireRate", "Fire Rate"), _fireRate(atk, delay), COLOR_TEXT],
			[Game.t("_Dps", "DPS"), _dps(atk, delay), COLOR_TEXT],
			[Game.t("_Range", "Range"), _positive(int(info.get("scope", 0))), COLOR_TEXT],
			[Game.t("_Reward", "Kill Reward"), str(int(info.get("reward", 0))), COLOR_GOLD],
			[Game.t("_EscapeCost", "Escape Loss"), str(int(info.get("lossPoints", 0))), COLOR_RED],
			[Game.t("_RewardExp", "Kill EXP"), str(int(info.get("rewardExp", 0))), COLOR_GOLD],
		],
	}


func _towerEntry(id: int) -> Dictionary:
	var info: Dictionary = Game.towerInfo.get(id, {})
	var atk: int = int(info.get("atk", 0))
	var reload: float = float(info.get("reload", 0.0))
	var gridSize: Vector2i = info.get("gridSize", Vector2i.ONE)
	return {
		"name": Game.getTowerDisplayName(id),
		"tag": "%s %d" % [Game.t("_Cost", "Cost"), int(info.get("cost", 0))],
		"desc": Game.t(str(info.get("desc", "")), ""),
		"icon": _icon(TOWERICONS, id),
		"color": COLOR_TEAL,
		"stat_columns": 4, # 8 项数值排两行
		"stats": [
			[Game.t("_Atk", "ATK"), str(atk), COLOR_TEXT],
			[Game.t("_FireRate", "Fire Rate"), _fireRate(atk, reload), COLOR_TEXT],
			[Game.t("_Dps", "DPS"), _dps(atk, reload), COLOR_TEXT],
			[Game.t("_Range", "Range"), str(int(info.get("scope", 0))), COLOR_TEXT],
			[Game.t("_HP", "HP"), str(int(info.get("hp", 0))), COLOR_TEXT],
			[Game.t("_Cost", "Cost"), str(int(info.get("cost", 0))), COLOR_GOLD],
			[Game.t("_InitTime", "Build Time"), "%.1fs" % float(info.get("initTime", 0.0)), COLOR_TEXT],
			[Game.t("_GridSize", "Grid"), "%dx%d" % [gridSize.x, gridSize.y], COLOR_TEXT],
		],
	}


# ---------- 图标层 ----------

## 按路径表取图。表里没写、或者路径不存在就返回 null（卡面空着，但不会报错）
func _icon(table: Dictionary, id: int) -> Texture2D:
	var path: String = str(table.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

# ---------- 工具 ----------

## 清空动态生成的子节点（先脱离父节点再 queue_free，避免同一帧里新旧内容同时存在）
func _clearChildren(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _yesNo(value: bool) -> String:
	return Game.t("_Yes", "Yes") if value else Game.t("_No", "No")


## 只有正数才有意义的值（不参战的敌人 scope / atk 都是 0）
func _positive(value: int) -> String:
	return str(value) if value > 0 else "--"


## 开火间隔(秒) -> 每秒攻击次数；atk=0 表示不参战，delay=0 表示自爆型的一次性伤害
func _fireRate(atk: int, delay_s: float) -> String:
	if atk <= 0:
		return "--"
	return Game.t("_OneShot", "One-shot") if delay_s <= 0.0 else "%.1f/s" % (1.0 / delay_s)


func _dps(atk: int, delay_s: float) -> String:
	if atk <= 0 or delay_s <= 0.0:
		return "--"
	return "%.1f" % (float(atk) / delay_s)
