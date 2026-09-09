extends PanelContainer
## 地图右侧塔信息面板：选中防御塔后，在右侧集中显示该塔的名称/等级/血量/经验与属性。

@onready var name_label: Label = $Margin/VBox/Header/nameLabel
@onready var level_label: Label = $Margin/VBox/Header/levelLabel
@onready var hp_title: Label = $Margin/VBox/HpRow/hpTitle
@onready var hp_value_label: Label = $Margin/VBox/HpRow/hpValueLabel
@onready var hp_bar: ProgressBar = $Margin/VBox/hpBar
@onready var exp_title: Label = $Margin/VBox/ExpRow/expTitle
@onready var exp_value_label: Label = $Margin/VBox/ExpRow/expValueLabel
@onready var exp_bar: ProgressBar = $Margin/VBox/expBar
@onready var atk_title: Label = $Margin/VBox/Stats/atkRow/Title
@onready var atk_value_label: Label = $Margin/VBox/Stats/atkRow/Value
@onready var reload_title: Label = $Margin/VBox/Stats/reloadRow/Title
@onready var reload_value_label: Label = $Margin/VBox/Stats/reloadRow/Value
@onready var scope_title: Label = $Margin/VBox/Stats/scopeRow/Title
@onready var scope_value_label: Label = $Margin/VBox/Stats/scopeRow/Value
@onready var cost_title: Label = $Margin/VBox/Economy/costRow/Title
@onready var cost_value_label: Label = $Margin/VBox/Economy/costRow/Value
@onready var sell_title: Label = $Margin/VBox/Economy/sellRow/Title
@onready var sell_value_label: Label = $Margin/VBox/Economy/sellRow/Value
@onready var hint_label: Label = $Margin/VBox/hintLabel

var tower: Node = null # 当前选中的塔


func _ready() -> void:
	visible = false
	hp_title.text = _t("_HP", "HP")
	exp_title.text = _t("_EXP", "EXP")
	atk_title.text = _t("_Atk", "ATK")
	reload_title.text = _t("_FireRate", "Fire Rate")
	scope_title.text = _t("_Range", "Range")
	cost_title.text = _t("_Cost", "Cost")
	sell_title.text = _t("_SellPrice", "Sell Price")
	hint_label.text = _t("_PanelHint", "Click the tower again or empty ground to deselect.")


# 选中塔 -> 显示该塔信息
func show_tower(t: Node) -> void:
	tower = t
	visible = true
	refresh()


# 取消选中 / 塔被出售 -> 隐藏面板
func clear() -> void:
	tower = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	# 塔在选中期间被出售/销毁时自动隐藏
	if tower == null or not is_instance_valid(tower):
		clear()
		return
	refresh()


func refresh() -> void:
	if not is_instance_valid(tower):
		return
	var t := tower as Tower
	if t == null:
		return

	# 名称与等级
	name_label.text = Game.get_tower_display_name(t.type)
	level_label.text = "Lv.%d" % maxi(1, t.level)

	# 血量
	var max_hp := maxi(1, t.maxHp)
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(t.hp, 0, max_hp)
	hp_value_label.text = "%d/%d" % [maxi(0, t.hp), max_hp]

	# 经验（满级 / 无升级配置时显示 MAX）
	var maxed: bool = t.level >= TowerUpgradeManager.MAX_LEVEL or not TowerUpgradeManager.configs.has(t.type)
	if maxed:
		exp_bar.max_value = 1
		exp_bar.value = 1
		exp_value_label.text = "MAX"
	else:
		var needed := int(TowerUpgradeManager.getExpThreshold(t.type, t.level))
		needed = maxi(1, needed)
		exp_bar.max_value = needed
		exp_bar.value = clampi(t.towerExp, 0, needed)
		exp_value_label.text = "%d/%d" % [t.towerExp, needed]

	# 属性与价格
	atk_value_label.text = str(t.atk)
	reload_value_label.text = _fmt_fire_rate(t.delay)
	scope_value_label.text = str(t.radarScope)
	cost_value_label.text = str(t.money)
	sell_value_label.text = str(t.sellingPrice)


# reload 为开火间隔(秒)，换算成每秒攻击次数展示
func _fmt_fire_rate(reload_s: float) -> String:
	if reload_s <= 0.0:
		return "--"
	return "%.1f/s" % (1.0 / reload_s)


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认英文文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
