extends Control
## 教程关的「新手引导」：半透明遮罩 + 在目标上挖个洞高亮 + 一步一步教玩家点哪。
##
## 刻意做成**独立场景**（scene/tutorial_guide.tscn），只有教程关会实例化它
## （见 map.gd::_setupTutorialGuide），其它关卡连这个场景都不会被加载。
##
## ── 为什么是"四周压暗"而不是"整屏压暗 + 挖洞" ──
## 挖洞要借助反向遮罩（CanvasGroup / 模板缓冲），多一项渲染技巧，还容易和
## CanvasLayer 的层级打架。这里把屏幕切成上/下/左/右 4 块深色矩形，
## 中间那块自然就透出来了 —— 不需要任何遮罩技巧，`_draw` 十行搞定。
##
## ── 一步怎么算完成（关键设计）──
## 遮罩 `mouse_filter = IGNORE`，玩家的点击照常落到底下的按钮 / 地图上，
## 引导**不截点击、只判断"这件事有没有发生"**：
##     · 开工具箱 → 轮询 towerUI.isOpen
##     · 选塔     → 听 Game.selectTower
##     · 建塔     → 听 Game.towerPlaced
##     · 点 ▶ 开始 → 轮询顶端按钮的 button_pressed
##     · 放技能   → **点一下就放行**（三种结果任意一种都算：瞬发生效 / 进入选目标 / 被拦下）
##     · 右键取消 → 不用判定：只在“已选中、还没落地”期间挂一行小字提示
##                  （见 _update_cancel_hint，跟着状态走而不是跟着步骤走）
## 好处：高亮的是**真按钮**，玩家做的是**真操作**，不存在
## "引导自己画了个假按钮，点完还要替玩家转发一次点击"这套破事。
##
## ── 为什么先教建塔、再教开打 ──
## 点 ▶ 之后敌人 1.6 秒一个地出来，新手还在读提示就已经漏怪了。
## 所以顺序是：开箱子 → 选塔 → 建塔 → 开打。
##
## 跳过：气泡里一直有「跳过引导」，随时点掉收工（本局不再出现，
## 重开本关会再来一次）。

## 收工（跳过 / 做完都算）
signal finished

## 遮罩颜色：压暗但不是全黑 —— 玩家还得看得见地图上发生了什么
const DIM_COLOR := Color(0.02, 0.03, 0.05, 0.62)
## 高亮描边色（和顶栏数字的金黄同一支）
const HILITE_COLOR := Color(1.0, 0.7764706, 0.101960786)
## 高亮框往外扩多少像素（贴着按钮描边太紧，扩一点好看）
const HOLE_PAD := 8.0
## 气泡与高亮框的间距
const BUBBLE_GAP := 18.0
## 气泡 / 高亮框离屏幕边的最小距离
const SCREEN_MARGIN := 16.0
## 光晕呼吸一圈的秒数
const RING_PERIOD := 1.6
## 教程关的关卡 id（StageData.allStage 里 'id': 0 那条）
const TUTORIAL_STAGE_ID := 0
## 想推荐给新手的塔：塔列表里优先高亮它的卡片
const TOWER_TO_HIGHLIGHT = Game.towerType.machineGunTower

@onready var bubble: PanelContainer = $Bubble
@onready var stepLabel: Label = $Bubble/VBox/stepLabel
@onready var textLabel: Label = $Bubble/VBox/textLabel
@onready var hintLabel: Label = $Bubble/VBox/hintLabel
@onready var actionBtn: Button = $Bubble/VBox/footer/actionBtn

## 宿主 map（借它拿 level / titleNode / towerUINode / abilityBar）
var map: Node = null

var _steps: Array = []
var _index: int = -1
## 当前高亮孔（屏幕坐标）。空 Rect2 = 没有目标，整屏压暗 + 气泡居中
var _hole: Rect2 = Rect2()
## 这一步挑中的可建造格（进场时挑一次，之后一直用它，免得高亮框乱跳）
var _buildCell: Vector2i = Vector2i(-1, -1)
## 最后一步（纯文字、气泡居中、按钮变「知道了」）
var _centered: bool = false
var _started: bool = false
var _finished: bool = false
var _pulse: float = 0.0
## 三个「玩家做过这件事」的标记，进入新的一步时清零
var _sawSelect: bool = false
var _sawPlace: bool = false
var _sawAbility: bool = false
## 塔信息面板被打开过（升级那一步的完成条件）
var _sawTowerPanel: bool = false

var _styleHole: StyleBoxFlat
var _styleRing: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	hintLabel.text = Game.t("_TutorialGuideCancelHint", "Right-click to cancel.")
	hintLabel.visible = false
	actionBtn.pressed.connect(_on_action_pressed)
	# 先隐身：map 建好、关卡情报弹窗关掉之后才 start()
	hide()


## ── 由 map 调用 ──
## 接上宿主、连信号、按当前存档情况决定有哪几步。
func setup(map_node: Node) -> void:
	map = map_node
	Game.selectTower.connect(_on_tower_selected)
	Game.towerPlaced.connect(_on_tower_placed)
	# 技能：**点一下就放行**，不等玩家真把技能砸到地图上 ——
	#   · 瞬发技能：点完直接生效          → abilityActivated
	#   · 范围技能：点完进入“选目标”状态  → selectionStarted
	#   · 宝石不够 / 冷却中被拦下           → abilityFailed
	# 三路都接。只要玩家点过就算完成，免得他卡在一个完不成的任务上。
	AbilityManager.abilityActivated.connect(_on_ability_activated)
	AbilityManager.selectionStarted.connect(_on_ability_selection_started)
	AbilityManager.abilityFailed.connect(_on_ability_failed)
	_build_steps()


## 由 map 调用：正式开始（教程关的情报弹窗关掉之后）。
func start() -> void:
	if _started or _finished or _steps.is_empty():
		return
	_started = true
	visible = not get_tree().paused
	_goto_step(0)


## 跳过引导（气泡按钮 / 外部调用都走这里）
func skip() -> void:
	_finish()


func _process(delta: float) -> void:
	if not _started or _finished:
		return
	# 暂停菜单挂在 PopupLayer（layer 10）上，比引导（layer 5）高 ——
	# 但引导的压暗层会把暂停菜单身后的画面再压暗一遍，看着很脏。
	# 所以暂停期间把自己收起来（process_mode = ALWAYS，暂停时也照常执行到这里）。
	var want_visible: bool = not get_tree().paused
	if visible != want_visible:
		visible = want_visible
	if not visible:
		return

	_pulse += delta
	# 相机在动、窗口在缩放 —— 每帧重算高亮框，让它一直贴着目标
	_refresh_hole()
	_update_cancel_hint()
	_place_bubble()
	queue_redraw()

	_track_tower_panel()
	if _step_done():
		_goto_step(_index + 1)


## 塔信息面板是不是被打开了？
## 面板是 map 自己的 @onready 字段，引导拿不到它的子节点变化信号，
## 所以每帧查一次 visible —— 和本文件其它步骤一样，只查状态、不截点击。
func _track_tower_panel() -> void:
	if _sawTowerPanel:
		return
	var p = _tower_detail_panel()
	if p != null and is_instance_valid(p) and bool(p.visible):
		_sawTowerPanel = true


# ===== 步骤表 =====
## 顺序＝玩家要做的动作顺序。文案走翻译表，取不到就用第二段英文兜底
## （语言文件要在编辑器里重新导入一次才会带上新键，见 lang/language.csv）。
func _build_steps() -> void:
	var tower_name: String = _highlighted_tower_name()
	_steps = [
		{
			"id": "toolbox",
			"target": "toolbox",
			"text": Game.t("_TutorialGuide1",
				"Tap the toolbox (top-left) to open the tower list."),
		},
		{
			"id": "tower_card",
			"target": "tower_card",
			"text": Game.t("_TutorialGuide2",
				"Tap a tower card to pick it — the %s is a good first one.") % tower_name,
		},
		{
			"id": "place",
			"target": "build_cell",
			"text": Game.t("_TutorialGuide3",
				"Now tap the highlighted cell to build it there."),
		},
		# ── 升级教学：**建完塔紧接着**教，因为塔就在眼前、点一下就开面板 ──
		# 这两个目标只有在这一步才解析：塔没建起来之前根本没有可点的塔。
		{
			"id": "tower_panel",
			"target": "tower_panel",
			"text": Game.t("_TutorialGuide6",
				"Tap your new tower to open its info panel."),
		},
		{
			"id": "upgrade",
			"target": "tower_detail",
			"info": true,
			"text": Game.t("_TutorialGuide7",
				"Towers level up by KILLING. Every kill fills the EXP bar; when it fills, the tower upgrades itself to Lv.2, then Lv.3 — higher damage, faster fire, longer range."),
		},
		{
			"id": "spread",
			"target": "tower_detail",
			"info": true,
			"text": Game.t("_TutorialGuide8",
				"So spread towers along the lane and let them keep killing. Lv.3 is the max."),
		},
		{
			"id": "start",
			"target": "btn_start",
			"text": Game.t("_TutorialGuide4",
				"Tap ▶ to send in the enemies. Hold the line!"),
		},
	]
	# 技能那一步只在玩家**真的放得出来**时才加：新存档宝石是 0，
	# 硬塞一步"放个技能"进去，玩家会卡在永远做不完的任务上。
	if _can_use_ability():
		_steps.append({
			"id": "ability",
			"target": "ability_slot",
			"text": Game.t("_TutorialGuide5",
				"Gems buy support: tap the ability icon, then tap the map where you want it."),
		})
	_steps.append({
		"id": "done",
		"target": "",
		"last": true,
		"text": Game.t("_TutorialGuideFinish",
			"That's the whole loop — survive all %d waves!") % _wave_count(),
	})


func _goto_step(i: int) -> void:
	if i >= _steps.size():
		_finish()
		return
	_index = i
	_sawSelect = false
	_sawPlace = false
	_sawAbility = false
	_sawTowerPanel = false
	_buildCell = Vector2i(-1, -1)
	var step: Dictionary = _steps[_index]
	stepLabel.text = "%d / %d" % [_index + 1, _steps.size()]
	textLabel.text = str(step.get("text", ""))
	_centered = bool(step.get("last", false))
	# 「知道了」有两种含义：
	#   · 最后一步：收工回家
	#   · 中间的纯说明步骤（升级那两步）：继续往下走
	# 中间步骤必须自己带一个推进按钮，否则玩家会卡死在那里 ——
	# 那两步讲的是"靠击杀升级"，而此刻战斗还没开始，塔一点经验都没有，
	# 没有任何可以轮询的状态能让它们自动完成。
	var info: bool = bool(step.get("info", false))
	if _centered or info:
		actionBtn.text = Game.t("_TutorialGuideOk", "Got it")
	else:
		actionBtn.text = Game.t("_TutorialGuideSkip", "Skip guide")
	# 文案换行数变了 → 气泡高度也变，重新量一次再摆
	bubble.reset_size()
	_refresh_hole()
	_place_bubble()
	queue_redraw()


## 这一步做完了吗？全部靠"查状态"，不靠截点击。
func _step_done() -> bool:
	if _index < 0 or _index >= _steps.size():
		return false
	match str(_steps[_index].get("id", "")):
		"toolbox":
			var ui = _tower_ui()
			return ui != null and bool(ui.isOpen)
		"tower_card":
			return _sawSelect
		"place":
			return _sawPlace
		"tower_panel":
			# 点塔 -> map._onTowerClicked -> towerDetailPanel.showTower()，面板变可见
			return _sawTowerPanel
		"start":
			var t = _title()
			# 顶栏 ▶/⏸ 是 toggle：button_pressed = true 就代表"正在打"
			return t != null and t.btnStart != null and bool(t.btnStart.button_pressed)
		"ability":
			return _sawAbility
	# upgrade / spread 是纯说明步骤：`info = true`，由 _on_action_pressed 推进
	return false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	hide()
	finished.emit()


func _on_action_pressed() -> void:
	# 中间的纯说明步骤：按钮是「知道了」，点它继续下一步，不结束引导
	if _index >= 0 and _index < _steps.size() and bool(_steps[_index].get("info", false)):
		_goto_step(_index + 1)
		return
	# 其余情况：中途是「跳过引导」，最后一步是「知道了」—— 两者都是收工
	_finish()


func _on_tower_selected(_type) -> void:
	_sawSelect = true


func _on_tower_placed(_type, _cost, _grid, _cover, _size) -> void:
	_sawPlace = true


func _on_ability_activated(_abilityId: String, _target) -> void:
	_sawAbility = true


## 范围技能：点图标之后进入“选目标”状态 —— 这一步到这里就算完成。
func _on_ability_selection_started(_abilityId: String) -> void:
	_sawAbility = true


## 宝石不够 / 冷却中被拦住：玩家确实点过了，也放行（不然这一步会卡死）。
func _on_ability_failed(_abilityId: String, _reason: String) -> void:
	_sawAbility = true


# ===== 「右键取消」提示 =====
## 跟着**状态**走，不跟着步骤走：只要玩家正处于“已选中、还没落地”的状态
## （选中了塔 / 技能在等选目标），气泡下面就挂一行小字告诉他怎么退出来；
## 平时这行是隐藏的，不占地方。
##
## ⚠️ 右键是**唯一**的取消方式：project.godot 里 selectCancel 只绑了 button_index = 2
##    （左键是 click = 1），没有键盘替代键。
func _update_cancel_hint() -> void:
	var active: bool = _selection_active()
	if hintLabel.visible == active:
		return
	hintLabel.visible = active
	# 多/少一行 → 气泡高度变了，重新量一次，免得文字跟气泡框错位
	bubble.reset_size()


## 现在是不是“选好了还没落地”？
func _selection_active() -> bool:
	if AbilityManager.isSelecting():
		return true
	var lv = _level()
	return lv != null and lv.towerShadow != null and bool(lv.towerShadow.active)


# ===== 高亮框 =====
func _build_styles() -> void:
	# 主描边：圆角、不填充（只描边，中间要保持"透"）
	_styleHole = StyleBoxFlat.new()
	_styleHole.draw_center = false
	_styleHole.border_color = HILITE_COLOR
	_styleHole.set_border_width_all(4)
	_styleHole.set_corner_radius_all(14)
	# 外圈：跟着时间呼吸的光晕
	_styleRing = StyleBoxFlat.new()
	_styleRing.draw_center = false
	_styleRing.border_color = HILITE_COLOR
	_styleRing.set_border_width_all(3)
	_styleRing.set_corner_radius_all(18)


func _refresh_hole() -> void:
	if _index < 0 or _index >= _steps.size():
		_hole = Rect2()
		return
	var step: Dictionary = _steps[_index]
	var rect: Rect2 = _target_rect(str(step.get("target", "")))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		_hole = _clamp_rect(rect.grow(HOLE_PAD))
	else:
		_hole = Rect2()


## 目标 → 屏幕矩形。取不到（节点没了 / 被藏起来了）就返回空矩形。
func _target_rect(id: String) -> Rect2:
	match id:
		"toolbox":
			var ui = _tower_ui()
			if ui != null:
				return _control_rect(ui.toolboxIcon)
		"tower_card":
			return _control_rect(_highlight_tower_card())
		"build_cell":
			return _cell_rect(_pick_build_cell())
		"tower_panel":
			# 高亮"刚建好的那座塔"。地图节点是 Node2D 不是 Control，
			# 所以走 _unit_rect（自己按相机变换算屏幕矩形），不能走 _control_rect。
			return _unit_rect(_guided_tower())
		"tower_detail":
			# 高亮右侧信息面板 —— 升级那两步就是让玩家看这块面板
			return _control_rect(_tower_detail_panel())
		"btn_start":
			var t = _title()
			if t != null:
				return _control_rect(t.btnStart)
		"ability_slot":
			return _control_rect(_first_ability_slot())
	return Rect2()


## Node2D（地图上的单位）的屏幕矩形。
## Control 用 get_global_transform_with_canvas()，Node2D 没有那个方法，
## 但它同样继承 CanvasItem，所以这个方法对两者都成立 —— 统一走这里也行。
func _unit_rect(node) -> Rect2:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return Rect2()
	var n2: Node2D = node
	var xf: Transform2D = n2.get_global_transform_with_canvas()
	# 塔的贴图最大 128x128，绕中心取一个固定方块当高亮框，别去猜贴图实际尺寸
	var side: float = 76.0 * xf.get_scale().x
	return Rect2(xf.origin - Vector2(side, side) * 0.5, Vector2(side, side))


## 控件的屏幕矩形。
## 用 get_global_transform_with_canvas() 而不是 get_global_rect()：Hud 是
## CanvasLayer，只有这个方法把"层级变换"也算进去，窗口缩放 / 层偏移下都准。
func _control_rect(c) -> Rect2:
	if c == null or not is_instance_valid(c) or not (c is Control):
		return Rect2()
	var ctrl: Control = c
	if not ctrl.is_visible_in_tree():
		return Rect2()
	var xf: Transform2D = ctrl.get_global_transform_with_canvas()
	var out: Rect2 = Rect2(xf.origin, ctrl.size * xf.get_scale())
	if out.size.x <= 0.0 or out.size.y <= 0.0:
		return Rect2()
	return out


## 一格地图的屏幕矩形（格坐标 → 关卡本地像素 → 屏幕，中间含相机变换）
func _cell_rect(grid: Vector2i) -> Rect2:
	if grid.x < 0 or grid.y < 0:
		return Rect2()
	var lv = _level()
	if lv == null:
		return Rect2()
	var tile: float = float(StageData.TileSize)
	var xf: Transform2D = lv.get_global_transform_with_canvas()
	var cell_size: Vector2 = xf.get_scale() * tile
	return Rect2(xf * Vector2(float(grid.x) * tile, float(grid.y) * tile), cell_size)


## 挑一格"完整露在屏幕里、离屏幕中心最近"的可建造格 —— 高亮框不会被裁，
## 玩家也一眼能看到它在哪。
func _pick_build_cell() -> Vector2i:
	if _buildCell.x >= 0:
		return _buildCell
	var lv = _level()
	if lv == null:
		return Vector2i(-1, -1)
	var allowed: Array = lv.allowArea
	if allowed.is_empty():
		return Vector2i(-1, -1)
	var screen: Rect2 = Rect2(Vector2.ZERO, size)
	var center: Vector2 = size * 0.5
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF
	for cell in allowed:
		var r: Rect2 = _cell_rect(cell)
		if not screen.encloses(r):
			continue
		var d: float = (r.get_center() - center).length()
		if d < best_dist:
			best_dist = d
			best = cell
	if best.x < 0:
		best = allowed[0]
	_buildCell = best
	return best


## 把高亮框夹回屏幕内（目标跑到屏幕外时至少还指个方向，不至于整屏全黑）
func _clamp_rect(r: Rect2) -> Rect2:
	var vp: Vector2 = size
	if r.size.x <= 0.0 or r.size.y <= 0.0 or vp.x <= 0.0 or vp.y <= 0.0:
		return Rect2()
	var m: float = 6.0
	var out: Rect2 = r
	out.position.x = clampf(out.position.x, m, maxf(m, vp.x - out.size.x - m))
	out.position.y = clampf(out.position.y, m, maxf(m, vp.y - out.size.y - m))
	return out


# ===== 画遮罩 =====
func _draw() -> void:
	if _hole.size.x <= 0.0 or _hole.size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), DIM_COLOR)
		return
	var h: Rect2 = _hole
	# 上 / 下 / 左 / 右 四块压暗，中间那块自然就是"洞"
	draw_rect(Rect2(0.0, 0.0, size.x, h.position.y), DIM_COLOR)
	draw_rect(Rect2(0.0, h.end.y, size.x, maxf(0.0, size.y - h.end.y)), DIM_COLOR)
	draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), DIM_COLOR)
	draw_rect(Rect2(h.end.x, h.position.y, maxf(0.0, size.x - h.end.x), h.size.y), DIM_COLOR)
	# 高亮描边 + 呼吸光晕（k: 0 = 收拢最亮，1 = 散开最淡）
	draw_style_box(_styleHole, h)
	var k: float = 0.5 + 0.5 * sin(_pulse * TAU / RING_PERIOD)
	_styleRing.border_color = Color(HILITE_COLOR.r, HILITE_COLOR.g, HILITE_COLOR.b,
		0.42 * (1.0 - k))
	draw_style_box(_styleRing, h.grow(4.0 + 12.0 * k))


# ===== 摆气泡 =====
func _place_bubble() -> void:
	var bs: Vector2 = bubble.size
	var vp: Vector2 = size
	if _centered or _hole.size.x <= 0.0:
		bubble.position = ((vp - bs) * 0.5).round()
		return
	# 优先放高亮框**下方**（不挡目标）；下方放不下就翻到上方；
	# 上下都放不下（目标很高很大）就贴着屏幕下缘。
	var below: float = _hole.end.y + BUBBLE_GAP
	var above: float = _hole.position.y - BUBBLE_GAP - bs.y
	var y: float = below
	if below + bs.y > vp.y - SCREEN_MARGIN:
		y = above
	if y < SCREEN_MARGIN:
		y = clampf(below, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.y - bs.y - SCREEN_MARGIN))
	var x: float = clampf(_hole.get_center().x - bs.x * 0.5, SCREEN_MARGIN,
		maxf(SCREEN_MARGIN, vp.x - bs.x - SCREEN_MARGIN))
	bubble.position = Vector2(x, y).round()


# ===== 宿主节点取用（都做了空判，节点缺失时这一步自动没高亮 / 自动跳过）=====
func _level():
	return map.level if map != null else null


func _title():
	return map.titleNode if map != null else null


func _tower_ui():
	return map.towerUINode if map != null else null


## 右侧塔信息面板（升级那两步要指着它）
func _tower_detail_panel():
	return map.towerDetailPanel if map != null else null


## 引导里"要玩家点的塔"：优先用地图当前选中的那座；
## 没选中就找离高亮格最近的那座 —— 也就是玩家刚刚建起来的那一座。
##
## ⚠️ 塔是挂在 **map** 下面的（map.gd::placeTower 里 `add_child(temp)`），
##    不是挂在 level 下面。去 level 的 children 里找永远是空的。
func _guided_tower():
	if map == null:
		return null
	var sel = map.get("selectedTower")
	if sel != null and is_instance_valid(sel):
		return sel
	var target_cell: Vector2i = _pick_build_cell()
	var best = null
	var best_d: float = INF
	for c in map.get_children():
		if not (c is Tower):
			continue
		var cover = c.get("coverGrid")
		if cover is Array and not (cover as Array).is_empty():
			var cell: Vector2i = (cover as Array)[0]
			var d: float = Vector2(cell - target_cell).length()
			if d < best_d:
				best_d = d
				best = c
		elif best == null:
			best = c   # 兜底：没有 coverGrid 信息就用第一个
	return best


func _ability_bar():
	return map.abilityBar if map != null else null


## 塔列表里要推荐的卡片：优先机枪塔，其次第一张没被禁的，最后兜底第一张
func _highlight_tower_card():
	var ui = _tower_ui()
	if ui == null:
		return null
	var list = ui.towerCardList
	if list == null:
		return null
	var fallback = null
	for card in list.get_children():
		if card.get("type") == TOWER_TO_HIGHLIGHT:
			return card
		if fallback == null and not bool(card.get("locked")):
			fallback = card
	if fallback != null:
		return fallback
	return list.get_child(0) if list.get_child_count() > 0 else null


func _highlighted_tower_name() -> String:
	var card = _highlight_tower_card()
	if card == null:
		return Game.getTowerDisplayName(TOWER_TO_HIGHLIGHT)
	return Game.getTowerDisplayName(card.get("type"))


func _first_ability_slot():
	var bar = _ability_bar()
	if bar == null or not bar.visible:
		return null
	var slots = bar.slots
	if slots == null or slots.get_child_count() == 0:
		return null
	return slots.get_child(0)


## 本关总波数（最后一句提示用）
func _wave_count() -> int:
	var lv = _level()
	if lv == null:
		return 0
	return int(lv.wave)


## 现在**放得出**技能吗？宝石不够就不加那一步，免得任务做不完。
func _can_use_ability() -> bool:
	if _first_ability_slot() == null:
		return false
	return UserData.gem >= AbilityManager.getGemCost("bombard")
