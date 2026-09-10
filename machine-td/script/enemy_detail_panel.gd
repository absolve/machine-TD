extends PanelContainer
## 地图右侧敌人信息面板：选中敌人后集中显示名称/定位/血量与属性。
## 与塔详情面板共用屏幕右侧同一个槽位（两者互斥显示）；
## 敌人死亡、逃脱或自爆后节点被释放，这里会自动收起面板。

@onready var name_label: Label = $Margin/VBox/Header/nameLabel
@onready var role_label: Label = $Margin/VBox/Header/roleLabel
@onready var hp_title: Label = $Margin/VBox/HpRow/hpTitle
@onready var hp_value_label: Label = $Margin/VBox/HpRow/hpValueLabel
@onready var hp_bar: ProgressBar = $Margin/VBox/hpBar
@onready var atk_title: Label = $Margin/VBox/Stats/atkRow/Title
@onready var atk_value_label: Label = $Margin/VBox/Stats/atkRow/Value
@onready var reload_title: Label = $Margin/VBox/Stats/reloadRow/Title
@onready var reload_value_label: Label = $Margin/VBox/Stats/reloadRow/Value
@onready var dps_title: Label = $Margin/VBox/Stats/dpsRow/Title
@onready var dps_value_label: Label = $Margin/VBox/Stats/dpsRow/Value
@onready var speed_title: Label = $Margin/VBox/Attr/speedRow/Title
@onready var speed_value_label: Label = $Margin/VBox/Attr/speedRow/Value
@onready var armor_title: Label = $Margin/VBox/Attr/armorRow/Title
@onready var armor_value_label: Label = $Margin/VBox/Attr/armorRow/Value
@onready var flying_title: Label = $Margin/VBox/Attr/flyingRow/Title
@onready var flying_value_label: Label = $Margin/VBox/Attr/flyingRow/Value
@onready var reward_title: Label = $Margin/VBox/Reward/rewardRow/Title
@onready var reward_value_label: Label = $Margin/VBox/Reward/rewardRow/Value
@onready var escape_title: Label = $Margin/VBox/Reward/escapeRow/Title
@onready var escape_value_label: Label = $Margin/VBox/Reward/escapeRow/Value
@onready var exp_title: Label = $Margin/VBox/Reward/expRow/Title
@onready var exp_value_label: Label = $Margin/VBox/Reward/expRow/Value
@onready var hint_label: Label = $Margin/VBox/hintLabel

var enemy: Node = null # 当前选中的敌人


func _ready() -> void:
	visible = false
	hp_title.text = _t("_HP", "HP")
	atk_title.text = _t("_Atk", "ATK")
	reload_title.text = _t("_FireRate", "Fire Rate")
	dps_title.text = _t("_Dps", "DPS")
	speed_title.text = _t("_Speed", "Speed")
	armor_title.text = _t("_Armor", "Armor")
	flying_title.text = _t("_Flying", "Flying")
	reward_title.text = _t("_Reward", "Kill Reward")
	escape_title.text = _t("_EscapeCost", "Escape Loss")
	exp_title.text = _t("_RewardExp", "Kill EXP")
	hint_label.text = _t("_EnemyPanelHint", "Click the enemy again or empty ground to deselect.")


# 选中敌人 -> 显示该敌人信息
func show_enemy(e: Node) -> void:
	enemy = e
	visible = true
	refresh()


# 取消选中 / 敌人已被消灭 -> 隐藏面板
func clear() -> void:
	enemy = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	# 敌人死亡、逃脱路径终点或自爆后节点被 queue_free，这里自动收起面板
	if enemy == null or not is_instance_valid(enemy):
		clear()
		return
	refresh()


func refresh() -> void:
	if not is_instance_valid(enemy):
		return
	var e := enemy as Enemy
	if e == null:
		return

	# 名称与行为定位
	name_label.text = Game.get_enemy_display_name(e.enemyType)
	role_label.text = Game.get_enemy_role_name(e.enemyType)

	# 血量
	var max_hp := maxi(1, e.maxHp)
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(e.hp, 0, max_hp)
	hp_value_label.text = "%d/%d" % [maxi(0, e.hp), max_hp]

	# 攻击力 / 开火间隔 / 每秒伤害
	atk_value_label.text = str(e.atk)
	if e.atk <= 0:
		reload_value_label.text = "--"
		dps_value_label.text = "--"
	elif e.shootDelay <= 0.0:
		# 自爆型：一次性总伤害，没有持续输出
		reload_value_label.text = _t("_OneShot", "One-shot")
		dps_value_label.text = "--"
	else:
		reload_value_label.text = _fmt_fire_rate(e.shootDelay)
		dps_value_label.text = "%.1f" % (float(e.atk) / e.shootDelay)

	# 移动与防护
	speed_value_label.text = str(e.speed)
	armor_value_label.text = "%d%%" % roundi(e.armor * 100.0)
	flying_value_label.text = _t("_Yes", "Yes") if e.flying else _t("_No", "No")

	# 收益与代价
	reward_value_label.text = str(e.reward)
	escape_value_label.text = str(e.lossPoints)
	exp_value_label.text = str(e.rewardExp)


# shootDelay 为开火间隔(秒)，换算成每秒攻击次数展示（与塔详情面板一致）
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
