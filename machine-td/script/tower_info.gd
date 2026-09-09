extends PanelContainer
## 悬停建造卡片时弹出的塔信息 tooltip（样式与 towerDetailPanel 一致）。

@onready var name_label: Label = $MarginContainer/vbox/nameLabel
@onready var desc_label: Label = $MarginContainer/vbox/descMargin/descLabel
@onready var atk_title: Label = $MarginContainer/vbox/Stats/atkRow/Title
@onready var atk_value: Label = $MarginContainer/vbox/Stats/atkRow/Value
@onready var reload_title: Label = $MarginContainer/vbox/Stats/reloadRow/Title
@onready var reload_value: Label = $MarginContainer/vbox/Stats/reloadRow/Value
@onready var scope_title: Label = $MarginContainer/vbox/Stats/scopeRow/Title
@onready var scope_value: Label = $MarginContainer/vbox/Stats/scopeRow/Value
@onready var cost_title: Label = $MarginContainer/vbox/Stats/costRow/Title
@onready var cost_value: Label = $MarginContainer/vbox/Stats/costRow/Value
@onready var hp_title: Label = $MarginContainer/vbox/Stats/hpRow/Title
@onready var hp_value: Label = $MarginContainer/vbox/Stats/hpRow/Value

func _ready() -> void:
	atk_title.text = _t("_Atk", "ATK")
	reload_title.text = _t("_FireRate", "Fire Rate")
	scope_title.text = _t("_Range", "Range")
	cost_title.text = _t("_Cost", "Cost")
	hp_title.text = _t("_HP", "HP")

func showDetail(obj, tower_type = 0):
	if tower_type:
		name_label.text = Game.get_tower_display_name(tower_type)
	else:
		name_label.text = str(obj.name)
	desc_label.text = tr(obj.desc)
	atk_value.text = str(obj.atk)
	reload_value.text = _fmt_fire_rate(float(obj.reload))
	scope_value.text = str(obj.scope)
	cost_value.text = str(obj.cost)
	hp_value.text = str(obj.get("hp", obj.get("maxHp", 0)))
	visible = true

func hideDetail():
	visible = false

# reload 为开火间隔(秒)，换算成每秒攻击次数展示（与 towerDetailPanel 一致）
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
