extends PanelContainer
## 悬停建造卡片时弹出的塔信息 tooltip（样式与 towerDetailPanel 一致）。

@onready var nameLabel: Label = $MarginContainer/vbox/nameLabel
@onready var descLabel: Label = $MarginContainer/vbox/descMargin/descLabel
@onready var atkTitle: Label = $MarginContainer/vbox/Stats/atkRow/Title
@onready var atkValue: Label = $MarginContainer/vbox/Stats/atkRow/Value
@onready var reloadTitle: Label = $MarginContainer/vbox/Stats/reloadRow/Title
@onready var reloadValue: Label = $MarginContainer/vbox/Stats/reloadRow/Value
@onready var scopeTitle: Label = $MarginContainer/vbox/Stats/scopeRow/Title
@onready var scopeValue: Label = $MarginContainer/vbox/Stats/scopeRow/Value
@onready var costTitle: Label = $MarginContainer/vbox/Stats/costRow/Title
@onready var costValue: Label = $MarginContainer/vbox/Stats/costRow/Value
@onready var hpTitle: Label = $MarginContainer/vbox/Stats/hpRow/Title
@onready var hpValue: Label = $MarginContainer/vbox/Stats/hpRow/Value

func _ready() -> void:
	atkTitle.text = Game.t("_Atk", "ATK")
	reloadTitle.text = Game.t("_FireRate", "Fire Rate")
	scopeTitle.text = Game.t("_Range", "Range")
	costTitle.text = Game.t("_Cost", "Cost")
	hpTitle.text = Game.t("_HP", "HP")

func showDetail(obj, tower_type = 0):
	if tower_type:
		nameLabel.text = Game.getTowerDisplayName(tower_type)
	else:
		# name 字段存的是翻译键，这里统一走 tr()
		nameLabel.text = tr(str(obj.get("name", "")))
	descLabel.text = tr(obj.desc)
	atkValue.text = str(obj.atk)
	reloadValue.text = _fmtFireRate(float(obj.reload))
	scopeValue.text = str(obj.scope)
	costValue.text = str(obj.cost)
	hpValue.text = str(obj.get("hp", obj.get("maxHp", 0)))
	visible = true

func hideDetail():
	visible = false

# reload 为开火间隔(秒)，换算成每秒攻击次数展示（与 towerDetailPanel 一致）
func _fmtFireRate(reload_s: float) -> String:
	if reload_s <= 0.0:
		return "--"
	return "%.1f/s" % (1.0 / reload_s)
