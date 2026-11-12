extends PanelContainer
## 单只 Boss 的血条行（多 Boss 堆叠时由 boss_health_bar.gd 创建和管理）。
##
## 从原来的单条血条拆出来：名字 / 血条 / 分段刻度 / 二阶段标签仍然沿用同一套皮肤，
## 只把"跟哪只 Boss"这件事下放到每一行，主脚本负责排序与显示上限。

const PHASE2_RATIO := 0.5

## 行高与血条厚度都压薄：多 Boss 时只占标题栏下方很窄的一条，
## 不挤占战斗视野，也不会碰到顶栏的金钱 / 波次 / 血量。
const SMALL_ROW_HEIGHT := 48.0
const BIG_ROW_HEIGHT := 56.0
const SMALL_BAR_HEIGHT := 10.0
const BIG_BAR_HEIGHT := 12.0

@onready var nameLabel: Label = $VBox/NameLabel
@onready var barRow: Control = $VBox/BarRow
@onready var bar: ProgressBar = $VBox/BarRow/Bar
@onready var ticks: Control = $VBox/BarRow/Ticks
@onready var phaseTag: Label = $VBox/PhaseTag

## 本行跟的 Boss（可能已失效，由主脚本负责回收）
var boss: Node = null
## 小 Boss 用紧凑行；大 Boss 保留原来的高度与字号
var compact: bool = false


func bind(target: Node) -> void:
	boss = target
	var info: Dictionary = Game.enemyInfo.get(int(target.get("enemyType")), {})
	var key: String = str(info.get("bossBarName", info.get("name", "")))
	nameLabel.text = tr(key) if not key.is_empty() else str(target.name)
	compact = int(target.get("bossTier")) < 2
	apply_compact()
	# 用 bossAuraColor 给每行一个身份色：多只 Boss 同时在场时靠颜色 + 名字区分
	apply_style(info.get("bossAuraColor", Palette.ALERT_500))
	refresh()


func isAlive() -> bool:
	return boss != null and is_instance_valid(boss) and not bool(boss.get("dead"))


func refresh() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var maxHp: int = maxi(1, int(boss.get("maxHp")))
	var hp: int = clampi(int(boss.get("hp")), 0, maxHp)
	var ratio: float = float(hp) / float(maxHp)

	bar.max_value = maxHp
	bar.value = hp

	var isBigBoss: bool = int(boss.get("bossTier")) >= 2
	var inPhase2: bool = isBigBoss and ratio <= PHASE2_RATIO
	bar.modulate = Palette.ALERT_HOT if inPhase2 else Color(1, 1, 1, 1)
	phaseTag.visible = inPhase2
	if ticks != null and bool(ticks.get("phase2")) != inPhase2:
		ticks.set("phase2", inPhase2)
		ticks.queue_redraw()


func apply_compact() -> void:
	custom_minimum_size = Vector2(0.0, SMALL_ROW_HEIGHT if compact else BIG_ROW_HEIGHT)
	nameLabel.add_theme_font_size_override("font_size", 24 if compact else 26)
	barRow.custom_minimum_size = Vector2(0.0, SMALL_BAR_HEIGHT if compact else BIG_BAR_HEIGHT)
	phaseTag.add_theme_font_size_override("font_size", 16 if compact else 17)


## 复制一份面板样式再改边框色，避免多行共享同一个 StyleBox 互相串色。
func apply_style(aura: Color) -> void:
	var base: StyleBox = get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base != null else null
	if sb != null:
		sb.border_color = aura
		sb.content_margin_top = 3.0 if compact else 4.0
		sb.content_margin_bottom = 3.0 if compact else 4.0
		add_theme_stylebox_override("panel", sb)
	nameLabel.add_theme_color_override("font_color", aura)
