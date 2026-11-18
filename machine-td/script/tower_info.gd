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
	resized.connect(queue_redraw)
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
	reloadValue.text = fmtFireRate(float(obj.reload))
	scopeValue.text = str(obj.scope)
	costValue.text = str(obj.cost)
	hpValue.text = str(obj.get("hp", obj.get("maxHp", 0)))
	# ⚠️ 必须收缩回内容尺寸，而且**要延后**到布局完成之后。
	# 面板是个**自由的 Control**（不在任何容器里），size 只会被"最小尺寸"往上撑，
	# 最小尺寸变小后不会自己缩回去。而刚填好文字那一瞬间 autowrap 的宽度还没生效，
	# 最小高度会被算成天量级，此时立刻 reset_size() 会被 custom_maximum_size 夹到 800，
	# 反而把自己撑满。所以用 call_deferred，等这一帧的布局跑完再贴。
	reset_size.call_deferred()
	visible = true

func hideDetail():
	visible = false

# reload 为开火间隔(秒)，换算成每秒攻击次数展示（与 towerDetailPanel 一致）
func fmtFireRate(reload_s: float) -> String:
	if reload_s <= 0.0:
		return "--"
	return "%.1f/s" % (1.0 / reload_s)


func _draw() -> void:
	PanelBrackets.paint(self)
