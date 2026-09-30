extends PanelContainer
## 地图右侧敌人信息面板：选中敌人后集中显示名称/定位/血量与属性。
## 与塔详情面板共用屏幕右侧同一个槽位（两者互斥显示）；
## 敌人死亡、逃脱或自爆后节点被释放，这里会自动收起面板。

@onready var nameLabel: Label = $Margin/VBox/Header/nameLabel
@onready var roleLabel: Label = $Margin/VBox/Header/roleLabel
@onready var hpTitle: Label = $Margin/VBox/HpRow/hpTitle
@onready var hpValueLabel: Label = $Margin/VBox/HpRow/hpValueLabel
@onready var hpBar: ProgressBar = $Margin/VBox/hpBar
@onready var atkTitle: Label = $Margin/VBox/Stats/atkRow/Title
@onready var atkValueLabel: Label = $Margin/VBox/Stats/atkRow/Value
@onready var reloadTitle: Label = $Margin/VBox/Stats/reloadRow/Title
@onready var reloadValueLabel: Label = $Margin/VBox/Stats/reloadRow/Value
@onready var dpsTitle: Label = $Margin/VBox/Stats/dpsRow/Title
@onready var dpsValueLabel: Label = $Margin/VBox/Stats/dpsRow/Value
@onready var speedTitle: Label = $Margin/VBox/Attr/speedRow/Title
@onready var speedValueLabel: Label = $Margin/VBox/Attr/speedRow/Value
@onready var armorTitle: Label = $Margin/VBox/Attr/armorRow/Title
@onready var armorValueLabel: Label = $Margin/VBox/Attr/armorRow/Value
@onready var flyingTitle: Label = $Margin/VBox/Attr/flyingRow/Title
@onready var flyingValueLabel: Label = $Margin/VBox/Attr/flyingRow/Value
@onready var rewardTitle: Label = $Margin/VBox/Reward/rewardRow/Title
@onready var rewardValueLabel: Label = $Margin/VBox/Reward/rewardRow/Value
@onready var escapeTitle: Label = $Margin/VBox/Reward/escapeRow/Title
@onready var escapeValueLabel: Label = $Margin/VBox/Reward/escapeRow/Value
@onready var expTitle: Label = $Margin/VBox/Reward/expRow/Title
@onready var expValueLabel: Label = $Margin/VBox/Reward/expRow/Value
@onready var hintLabel: Label = $Margin/VBox/hintLabel

var enemy: Node = null # 当前选中的敌人


func _ready() -> void:
	visible = false
	hpTitle.text = Game.t("_HP", "HP")
	atkTitle.text = Game.t("_Atk", "ATK")
	reloadTitle.text = Game.t("_FireRate", "Fire Rate")
	dpsTitle.text = Game.t("_Dps", "DPS")
	speedTitle.text = Game.t("_Speed", "Speed")
	armorTitle.text = Game.t("_Armor", "Armor")
	flyingTitle.text = Game.t("_Flying", "Flying")
	rewardTitle.text = Game.t("_Reward", "Kill Reward")
	escapeTitle.text = Game.t("_EscapeCost", "Escape Loss")
	expTitle.text = Game.t("_RewardExp", "Kill EXP")
	hintLabel.text = Game.t("_EnemyPanelHint", "Click the enemy again or empty ground to deselect.")


# 选中敌人 -> 显示该敌人信息
func showEnemy(e: Node) -> void:
	enemy = e
	visible = true
	refresh()


# 取消选中 / 敌人已被消灭 -> 隐藏面板
func clear() -> void:
	enemy = null
	visible = false


func refresh() -> void:
	if not is_instance_valid(enemy):
		return
	var e: Enemy = enemy as Enemy
	if e == null:
		return

	# 名称与行为定位
	nameLabel.text = Game.getEnemyDisplayName(e.enemyType)
	roleLabel.text = Game.getEnemyRoleName(e.enemyType)

	# 血量
	var maxHp: int = maxi(1, e.maxHp)
	hpBar.max_value = maxHp
	hpBar.value = clampi(e.hp, 0, maxHp)
	hpValueLabel.text = "%d/%d" % [maxi(0, e.hp), maxHp]

	# 攻击力 / 开火间隔 / 每秒伤害
	atkValueLabel.text = str(e.atk)
	if e.atk <= 0:
		reloadValueLabel.text = "--"
		dpsValueLabel.text = "--"
	elif e.shootDelay <= 0.0:
		# 自爆型：一次性总伤害，没有持续输出
		reloadValueLabel.text = Game.t("_OneShot", "One-shot")
		dpsValueLabel.text = "--"
	else:
		reloadValueLabel.text = _fmtFireRate(e.shootDelay)
		dpsValueLabel.text = "%.1f" % (float(e.atk) / e.shootDelay)

	# 移动与防护
	speedValueLabel.text = str(e.speed)
	armorValueLabel.text = "%d%%" % roundi(e.armor * 100.0)
	flyingValueLabel.text = Game.t("_Yes", "Yes") if e.flying else Game.t("_No", "No")

	# 收益与代价
	rewardValueLabel.text = str(e.reward)
	escapeValueLabel.text = str(e.lossPoints)
	expValueLabel.text = str(e.rewardExp)


# shootDelay 为开火间隔(秒)，换算成每秒攻击次数展示（与塔详情面板一致）
func _fmtFireRate(reload_s: float) -> String:
	if reload_s <= 0.0:
		return "--"
	return "%.1f/s" % (1.0 / reload_s)


func _process(_delta: float) -> void:
	if not visible:
		return
	# 敌人死亡、逃脱路径终点或自爆后节点被 queue_free，这里自动收起面板
	if enemy == null or not is_instance_valid(enemy):
		clear()
		return
	refresh()
