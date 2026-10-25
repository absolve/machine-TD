extends PanelContainer
## 地图右侧塔信息面板：选中防御塔后，在右侧集中显示该塔的名称/等级/血量/经验与属性。

@onready var nameLabel: Label = $Margin/VBox/Header/nameLabel
@onready var levelLabel: Label = $Margin/VBox/Level/levelLabel
@onready var hpTitle: Label = $Margin/VBox/HpRow/hpTitle
@onready var hpValueLabel: Label = $Margin/VBox/HpRow/hpValueLabel
@onready var hpBar: ProgressBar = $Margin/VBox/hpBar
@onready var expTitle: Label = $Margin/VBox/ExpRow/expTitle
@onready var expValueLabel: Label = $Margin/VBox/ExpRow/expValueLabel
@onready var expBar: ProgressBar = $Margin/VBox/expBar
@onready var atkTitle: Label = $Margin/VBox/Stats/atkRow/Title
@onready var atkValueLabel: Label = $Margin/VBox/Stats/atkRow/Value
@onready var reloadTitle: Label = $Margin/VBox/Stats/reloadRow/Title
@onready var reloadValueLabel: Label = $Margin/VBox/Stats/reloadRow/Value
@onready var scopeTitle: Label = $Margin/VBox/Stats/scopeRow/Title
@onready var scopeValueLabel: Label = $Margin/VBox/Stats/scopeRow/Value
@onready var costTitle: Label = $Margin/VBox/Economy/costRow/Title
@onready var costValueLabel: Label = $Margin/VBox/Economy/costRow/Value
@onready var btnRepair: Button = $Margin/VBox/ActionRow/btnRepair
@onready var btnSell: Button = $Margin/VBox/ActionRow/btnSell
## 主动技能单独占一行（需求：技能按钮不和修理/出售挤在同一行）
@onready var skillRow: HBoxContainer = $Margin/VBox/SkillRow
@onready var btnSkill: Button = $Margin/VBox/SkillRow/btnSkill
@onready var hintLabel: Label = $Margin/VBox/hintLabel

var tower: Node = null # 当前选中的塔
# 缓存按钮文案，避免每帧刷新时反复触发布局重算
var lastRepairText: String = ""
var lastSellText: String = ""
var lastSkillText: String = ""


func _ready() -> void:
	visible = false
	hpTitle.text = Game.t("_HP", "HP")
	expTitle.text = Game.t("_EXP", "EXP")
	atkTitle.text = Game.t("_Atk", "ATK")
	reloadTitle.text = Game.t("_FireRate", "Fire Rate")
	scopeTitle.text = Game.t("_Range", "Range")
	costTitle.text = Game.t("_Cost", "Cost")
	hintLabel.text = Game.t("_PanelHint", "Click the tower again or empty ground to deselect.")
	btnRepair.pressed.connect(onRepairPressed)
	btnSell.pressed.connect(onSellPressed)
	btnSkill.pressed.connect(onSkillPressed)
	skillRow.visible = false
	refreshActionText()


# 修理按钮文案：满血时提示无需修理，否则显示“修理 + 费用”
func refreshActionText() -> void:
	var repairText: String = Game.t("_RepairFull", "HP Full")
	var sellText: String = Game.t("_Sell", "Sell")
	if is_instance_valid(tower):
		var t: Tower = tower as Tower
		if t != null:
			if t.repairCost > 0:
				repairText = "%s %d" % [Game.t("_Repair", "Repair"), t.repairCost]
			sellText = "%s %d" % [Game.t("_Sell", "Sell"), int(t.sellingPrice)]
	if repairText != lastRepairText:
		lastRepairText = repairText
		btnRepair.text = repairText
	if sellText != lastSellText:
		lastSellText = sellText
		btnSell.text = sellText


func onRepairPressed() -> void:
	var t: Tower = tower as Tower
	if t == null or not is_instance_valid(t):
		return
	t.requestRepair()


func onSellPressed() -> void:
	var t: Tower = tower as Tower
	if t == null or not is_instance_valid(t):
		return
	t.sell()


## 技能按钮。真正的判定在塔自己那边（`useSkill()` 会再走一遍 canUseSkill），
## 这里不做业务判断，避免"按钮看着能点、实际上被拒"这种两套逻辑不同步的问题。
func onSkillPressed() -> void:
	var t: Tower = tower as Tower
	if t == null or not is_instance_valid(t):
		return
	t.useSkill()
	refreshSkillButton(t)


# 选中塔 -> 显示该塔信息
func showTower(t: Node) -> void:
	tower = t
	visible = true
	refresh()


# 取消选中 / 塔被出售 -> 隐藏面板
func clear() -> void:
	tower = null
	visible = false


func refresh() -> void:
	if not is_instance_valid(tower):
		return
	var t: Tower = tower as Tower
	if t == null:
		return

	# 名称与等级
	nameLabel.text = Game.getTowerDisplayName(t.type)
	levelLabel.text = "Lv.%d" % maxi(1, t.level)

	# 血量
	var maxHp: int = maxi(1, t.maxHp)
	hpBar.max_value = maxHp
	hpBar.value = clampi(t.hp, 0, maxHp)
	hpValueLabel.text = "%d/%d" % [maxi(0, t.hp), maxHp]

	# 经验（满级 / 该塔不参与升级时显示 MAX）
	var maxed: bool = t.level >= TowerUpgradeManager.MAX_LEVEL or not TowerUpgradeManager.canUpgrade(t.type)
	if maxed:
		expBar.max_value = 1
		expBar.value = 1
		expValueLabel.text = "MAX"
	else:
		var needed: int = int(TowerUpgradeManager.getExpThreshold(t.type, t.level))
		needed = maxi(1, needed)
		expBar.max_value = needed
		expBar.value = clampi(t.towerExp, 0, needed)
		expValueLabel.text = "%d/%d" % [t.towerExp, needed]

	# 属性与价格。**显示派生值**：技能切换/生效时面板要跟着变，
	# 否则玩家切到"单体打击"却看到攻击力没涨，会以为技能没生效。
	atkValueLabel.text = str(t.effectiveAtk())
	reloadValueLabel.text = fmtFireRate(t.effectiveDelay())
	scopeValueLabel.text = str(int(round(t.effectiveScope())))
	costValueLabel.text = str(t.money)

	# 操作按钮：满血时修理按钮不可点，其余状态实时显示修理费与出售价
	var repairCost: int = t.repairCost
	btnRepair.disabled = repairCost <= 0
	btnSell.disabled = false
	refreshActionText()
	refreshSkillButton(t)


## 技能按钮：单独一行、文案随三种 kind 变、冷却/生效/停摆都显示倒计时。
func refreshSkillButton(t: Tower) -> void:
	if t == null:
		skillRow.visible = false
		return
	var has: bool = t.hasSkill()
	skillRow.visible = has
	if not has:
		return
	var skillName: String = tr(str(t.skillDef.get("name", "")))
	var text: String = ""
	if t.skillKind == "toggle":
		text = Game.t("_SkillToggle", "Switch: %s") % skillName
		btnSkill.button_pressed = t.skillOn
	elif t.skillKind == "instant":
		text = Game.t("_SkillUse", "Use: %s") % skillName
		btnSkill.button_pressed = false
	else:
		text = Game.t("_SkillUse", "Use: %s") % skillName
		btnSkill.button_pressed = t.isSkillActive()

	# 倒计时：生效中显示剩余持续时间；停摆显示停摆剩余；否则显示冷却
	if t.isSkillActive():
		text = "%s  %ds" % [text, int(ceil(t.skillActiveLeft))]
	elif t.isDisabled():
		text = "%s  %ds" % [text, int(ceil(t.skillDisabledLeft))]
	elif t.skillCooldownLeft > 0.0:
		text = "%s  %ds" % [text, int(ceil(t.skillCooldownLeft))]

	# 生效/启用时用安全黄强调，和"我方强化"的视觉约定一致
	if t.isSkillActive() or (t.skillKind == "toggle" and t.skillOn):
		btnSkill.modulate = Color(1.0, 0.86, 0.45, 1.0)
	else:
		btnSkill.modulate = Color(1, 1, 1, 1)

	btnSkill.disabled = not t.canUseSkill()
	if text != lastSkillText:
		lastSkillText = text
		btnSkill.text = text


# reload 为开火间隔(秒)，换算成每秒攻击次数展示
func fmtFireRate(reload_s: float) -> String:
	if reload_s <= 0.0:
		return "--"
	return "%.1f/s" % (1.0 / reload_s)


func _process(_delta: float) -> void:
	if not visible:
		return
	# 塔在选中期间被出售/销毁时自动隐藏
	if tower == null or not is_instance_valid(tower):
		clear()
		return
	refresh()
