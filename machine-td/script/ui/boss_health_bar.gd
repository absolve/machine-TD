extends Control
## Boss 顶部血条（设计见 feature_design.md §十九 19.8）
##
## 与敌人头顶的 `life_bar.tscn` 是**两套**，刻意不复用：
##   · life_bar 根是 Node2D，挂在敌人身上跟着走，语义是"被击中才亮 3 秒"
##   · 这里要钉在屏幕顶部、以 Control 的形态常驻，直到 boss 死
##
## 多 Boss 支持（2026-11-02）：
##   以前同一时刻只显示一只（大优先、同级最新），第二只 Boss 会顶掉第一只的血条。
##   现在改成**多行堆叠**：每只活着的 Boss 占一行，按"大 Boss 在上、同级按出生顺序"排列。
##   最多完整显示 MAX_ROWS 行（当前 2 行），多出来的收进「+N」条；
##   整体固定在**标题栏正下方居中**（top=112），不遮住顶栏的金钱 / 波次 / 血量信息。
##
## 信号仍然是按实例发的（enemy.gd 的 bossSpawned / bossDefeated），
## 所以这里用 rows 字典按 Boss 节点管理行，不再有"当前只跟一只"的状态。

## 最多完整显示几行；超出部分折叠成「+N Boss」。
## 取 2 是为了给顶栏（波次 / 血量 / 金币 / 宝石）留出安全区 —— Boss 多的时候
## 第三只起只报数量，不再继续往下堆。
const MAX_ROWS: int = 2
const ROW_SCENE := preload("res://scene/ui/boss_health_row.tscn")

@onready var rowsBox: VBoxContainer = $Stack/Rows
@onready var overflowRow: PanelContainer = $Stack/OverflowRow
@onready var overflowLabel: Label = $Stack/OverflowRow/Label

## Boss 实例 -> 血条行节点
var rows: Dictionary = {}


func _ready() -> void:
	visible = false
	Game.bossSpawned.connect(onBossSpawned)
	Game.bossDefeated.connect(onBossDefeated)


func onBossSpawned(newBoss: Node) -> void:
	if not is_instance_valid(newBoss):
		return
	if not bool(newBoss.get("isBoss")):
		return
	if rows.has(newBoss):
		return
	var row: Node = ROW_SCENE.instantiate()
	# 必须先入树再 bind：row 的 @onready 节点在 _ready 时才赋值。
	rowsBox.add_child(row)
	row.bind(newBoss)
	rows[newBoss] = row
	syncRows()


func onBossDefeated(defeated: Node) -> void:
	if not rows.has(defeated):
		return
	removeRow(defeated)
	syncRows()


## target 不写 Node：Boss 可能已被释放，带类型的参数会拒绝"previously freed"对象。
func removeRow(target) -> void:
	var row: Node = rows.get(target)
	rows.erase(target)
	if row != null and is_instance_valid(row):
		row.queue_free()


## 每帧刷新可见行；Boss 被别的途径释放（测试场景清场等）时补一次整理。
func _process(_delta: float) -> void:
	if rows.is_empty():
		return
	var changed: bool = false
	for target in rows.keys():
		var row: Node = rows[target]
		if not is_instance_valid(target) or bool(target.get("dead")) \
				or not is_instance_valid(row):
			removeRow(target)
			changed = true
			continue
		if row.visible:
			row.refresh()
	if changed:
		syncRows()


## 重排与显隐：大 Boss 在上、同级按出生序号从早到晚（新刷的小 Boss 不会顶掉旧行）。
func syncRows() -> void:
	var alive: Array = []
	for target in rows.keys():
		if is_instance_valid(target) and not bool(target.get("dead")):
			alive.append(target)
	alive.sort_custom(sortBosses)

	for i in alive.size():
		var row: Node = rows[alive[i]]
		if i < MAX_ROWS:
			rowsBox.move_child(row, i)
			row.visible = true
			row.refresh()
		else:
			row.visible = false

	var hidden: int = maxi(0, alive.size() - MAX_ROWS)
	overflowRow.visible = hidden > 0
	if hidden > 0:
		overflowLabel.text = Game.t("_BossOverflowFmt", "还有 %d 只 Boss") % hidden
	visible = not alive.is_empty()


func sortBosses(a: Node, b: Node) -> bool:
	var ta: int = int(a.get("bossTier"))
	var tb: int = int(b.get("bossTier"))
	if ta != tb:
		return ta > tb
	return int(a.get("spawnSeq")) < int(b.get("spawnSeq"))
