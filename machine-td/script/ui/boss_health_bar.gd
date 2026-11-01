extends Control
## Boss 顶部血条（设计见 feature_design.md §十九 19.8）
##
## 与敌人头顶的 `life_bar.tscn` 是**两套**，刻意不复用：
##   · life_bar 根是 Node2D，挂在敌人身上跟着走，语义是"被击中才亮 3 秒"
##   · 这里要钉在屏幕顶部、以 Control 的形态常驻，直到 boss 死
## 但**皮肤**复用 `theme/style/tower_bar_bg.tres` + `tower_hp_fill.tres`，
## 和详情面板 / 塔状态条是同一套视觉。
##
## 谁来决定显示谁：见 `onBossSpawned()` 的优先级规则。

## 大 boss 二阶段的血量比例（低于它就不是"变色"那么简单，见 PhaseTag）
const PHASE2_RATIO := 0.5

@onready var nameLabel: Label = $Panel/VBox/NameLabel
@onready var bar: ProgressBar = $Panel/VBox/BarRow/Bar
@onready var ticks: Control = $Panel/VBox/BarRow/Ticks
@onready var phaseTag: Label = $Panel/VBox/PhaseTag

## 当前跟的那只 boss（可能为 null）
var boss: Node = null


func _ready() -> void:
	visible = false
	Game.bossSpawned.connect(onBossSpawned)
	Game.bossDefeated.connect(onBossDefeated)


## 同一时刻可能有两只 boss（小 boss 没打死、大 boss 就出来了）。
## 规则：**不堆叠，只显示一只** ——
##   · 大 boss 优先于小 boss
##   · 同级取最新出生的那只
## 这样永远不会挡到上面那排 HUD（波次 / 血量 / 金币 / 宝石）。
func onBossSpawned(newBoss: Node) -> void:
	if not is_instance_valid(newBoss):
		return
	if boss != null and is_instance_valid(boss) and not bool(boss.get("dead")):
		var currentTier: int = int(boss.get("bossTier"))
		var newTier: int = int(newBoss.get("bossTier"))
		if newTier < currentTier:
			return
	bind(newBoss)


func onBossDefeated(defeated: Node) -> void:
	if defeated != boss:
		return
	boss = null
	# 还有别的 boss 在场就切过去（大优先），否则收起
	rebindFromScene()


func bind(target: Node) -> void:
	if not is_instance_valid(target):
		return
	boss = target
	var info: Dictionary = Game.enemyInfo.get(int(target.get("enemyType")), {})
	var key: String = str(info.get("bossBarName", info.get("name", "")))
	nameLabel.text = tr(key) if not key.is_empty() else str(target.name)
	visible = true
	refresh()


func unbind() -> void:
	boss = null
	visible = false


## 从场上所有活着的 boss 里挑一只（大优先，同级取最后找到的 = 最新）
func rebindFromScene() -> void:
	var best: Node = null
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or not bool(node.get("isBoss")):
			continue
		if bool(node.get("dead")):
			continue
		if best == null or betterThan(node, best):
			best = node
	if best != null:
		bind(best)
	else:
		unbind()


## 谁更应该显示：先比 tier（大 boss 优先），同级比出生序号（新的优先）。
## ⚠️ 不能用 `get_nodes_in_group()` 的顺序当"最新" —— 那个顺序没有保证。
func betterThan(a: Node, b: Node) -> bool:
	var ta: int = int(a.get("bossTier"))
	var tb: int = int(b.get("bossTier"))
	if ta != tb:
		return ta > tb
	return int(a.get("spawnSeq")) > int(b.get("spawnSeq"))


func _process(_delta: float) -> void:
	if boss == null:
		return
	if not is_instance_valid(boss) or bool(boss.get("dead")):
		# boss 被别的途径清掉了（例如测试场景的"清空"），换一只或收起
		boss = null
		rebindFromScene()
		return
	refresh()


func refresh() -> void:
	if boss == null or not is_instance_valid(boss):
		visible = false
		return
	var maxHp: int = maxi(1, int(boss.get("maxHp")))
	var hp: int = clampi(int(boss.get("hp")), 0, maxHp)
	var ratio: float = float(hp) / float(maxHp)

	bar.max_value = maxHp
	bar.value = hp

	var isBigBoss: bool = int(boss.get("bossTier")) >= 2
	var inPhase2: bool = isBigBoss and ratio <= PHASE2_RATIO
	# 二阶段：填充条转橙红 + 出现"二阶段"标签。玩家能预期它要狂暴了。
	bar.modulate = Color(1.0, 0.62, 0.42, 1.0) if inPhase2 else Color(1, 1, 1, 1)
	phaseTag.visible = inPhase2
	if ticks != null and ticks.get("phase2") != inPhase2:
		ticks.set("phase2", inPhase2)
		ticks.queue_redraw()
