extends Node2D
## 敌人残骸（feature_design.md §十一）。
##
## 地面敌人被击杀后在原地留一坨残骸，存活一段时间后自行淡出消失；
## 期间可以被移动机甲（mech.gd）用激光回收，换回一点金币。
##
## ── 为什么不用对象池 ──
## 与命中特效（ExplosionManage 池化）不同：残骸数量受"上一波敌人数量"限制、
## 而且每个都挂着自己的存活计时器与回收进度，池化要重置的状态太多、收益低。
## 等实测发现同屏上百再考虑（§11.3）。
##
## ── 为什么自己建 Sprite2D 而不是在场景里摆 ──
## 残骸要显示"**是哪一种敌人**的尸体"，贴图得从死掉的那个敌人身上取，
## 而那是运行期才知道的。场景里固定一张贴图做不到这件事。

## 残骸进入这个组，机甲靠它索敌（mech.gd::pickSalvageTarget）
const GROUP := "wreckage"
## 剩余时间低于这个比例开始闪烁，提示"快消失了"
const BLINK_BELOW := 0.25
## 闪烁频率（次/秒）
const BLINK_HZ := 6.0
## 回收价 = 原价 × 这个比例（§11.2）
const SCRAP_RATIO := 0.10
## 回收价下限。
##
## ⚠️ 平衡开关（§11.2 明确提示过）：第 1 关有 99 只迷你坦克（reward 5），
##    按"至少 1"算全回收是 +99 金币（初始 150），接近翻倍 —— 可能太强。
##    想削弱就把这里改成 0，并让 scrapValue 为 0 时**不掉残骸**（见 scrapValueFor）。
const SCRAP_MIN := 1

## ── 存活时长的加成系数 ──
##
## ⚠️ 用户反馈"残骸消失得太快"：原本是 8/10/12/16 秒（§11.2 的表），
##    而机甲要**开过去**才能收 —— 移动 220px/s，战场对角线动辄 1500px 以上，
##    开过去就要 7 秒，等于残骸还没等到就已经没了，回收基本用不上。
##    这里整体放大 2.25 倍（8→18 / 10→22 / 12→27 / 16→36 秒），
##    给机甲留出"接到通知 → 开过去 → 吸 1.2 秒"的完整窗口。
##    想调回去只改这一个系数即可，各档位的相对关系不变。
const LIFETIME_SCALE := 2.25

## 这坨残骸能回收多少钱
var scrapValue: int = 0
## 存活总时长（秒），由 setup 传进来
var lifetime: float = 18.0
## 已经活了多久
var age: float = 0.0
## 正在被机甲回收时 0~1（机甲会写这个值，用来画进度环）
var salvageProgress: float = 0.0
## 是否正在被回收（回收期间冻结存活倒计时 —— 否则快过期的残骸会在作业途中消失）
var salvaging: bool = false
## 淡出中标记，避免重复触发
var fading: bool = false

var sprite: Sprite2D
## 冒烟粒子（场景里那个 CPUParticles2D）
var smoke: CPUParticles2D
## 进度环（独立的子节点，见 RING 的注释）
var ring: Node2D


## 进度环。
##
## ⚠️ 必须是**独立的子节点**，不能直接在 wreckage 自己的 `_draw()` 里画：
##    父节点的 `_draw()` 先于子节点渲染，而残骸贴图是子节点 `Sprite` ——
##    结果就是环被自己的贴图整个盖住，看起来"进度条没显示"（用户实测报的就是这个）。
##    给它一个高 `z_index`，它就画在贴图上面了。
##
## 写成内部类而不是再开一个 .gd：这段逻辑只服务残骸，独立成文件反而多一层跳转。
class SalvageRing:
	extends Node2D
	## 环半径（像素）
	const RADIUS := 30.0
	## 环色：电青，与"我方作业"的其它能量色一致
	const COLOR := Color(0.435, 0.839, 0.918, 1.0)

	var progress: float = 0.0

	func _draw() -> void:
		if progress <= 0.0:
			return
		# 底圈（未完成部分）
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40,
			Color(COLOR.r, COLOR.g, COLOR.b, 0.30), 5.0)
		# 已完成弧：从 12 点方向顺时针长
		draw_arc(Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0),
			40, COLOR, 5.0)


## 由 enemy.gd 在死亡分支里调用。
##   tex    敌人的身体贴图（哪一帧不重要，取当前帧即可）
##   reward 该敌人的击杀金币，用来算回收价
##   life   存活时长（秒，未乘 LIFETIME_SCALE）
##
## ⚠️ 调用时机可能早于 `_ready()`（节点刚 instantiate 还没 add_child 时就能写贴图），
##    所以这里自己 get_node 兜一次，不能依赖 `@onready`。
func setup(tex: Texture2D, reward: int, life: float) -> void:
	scrapValue = scrapValueFor(reward)
	lifetime = maxf(0.1, life) * LIFETIME_SCALE
	var s: Sprite2D = sprite if sprite != null else get_node_or_null("Sprite")
	if s != null and tex != null:
		s.texture = tex


## 由回收价规则算钱：`max(SCRAP_MIN, floor(reward * SCRAP_RATIO))`。
## 抽成静态函数，好让探针直接核对 §11.2 那张表，不用去构造一个残骸节点。
static func scrapValueFor(reward: int) -> int:
	return maxi(SCRAP_MIN, int(floor(float(reward) * SCRAP_RATIO)))


func _ready() -> void:
	add_to_group(GROUP)
	# 视觉：压暗 + 随机倾斜，读作"报废"（§11.5）。
	# ⚠️ art_style / §11.5 都强调**不能画亮** —— 亮残骸会和活着的敌人混淆。
	modulate = Color(0.62, 0.58, 0.56, 1.0)
	rotation = deg_to_rad(randf_range(-12.0, 12.0))
	# 生成时从 0.7 弹到 1.0
	scale = Vector2.ONE * 0.7
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 冒烟：刚出现时冒一阵（"还在烧"），一段时间后自己停掉，不必等到残骸消失。
	smoke = get_node_or_null("Smoke") as CPUParticles2D
	if smoke != null:
		smoke.emitting = true
	# 进度环
	ring = get_node_or_null("SalvageRing") as Node2D
	if ring == null:
		# 场景里漏摆时兜底建一个，免得"回收没反馈"这种问题又要靠猜
		ring = SalvageRing.new()
		ring.name = "SalvageRing"
		ring.z_index = 10
		add_child(ring)


## 冒烟持续时长（秒）。到点后只停**新粒子**，已经在空中的会自己飘完，不会硬切。
const SMOKE_SECONDS := 4.0


func _process(delta: float) -> void:
	if fading:
		return
	# ⚠️ 回收期间**冻结存活倒计时**，但**不能整个 return** ——
	#    进度环要靠这里刷新，一 return 环就不动了（"回收时看不到进度"）。
	#    被回收中还在倒计时的话，残骸可能在作业途中到期消失，机甲白干一场。
	if not salvaging:
		age += delta
		# 冒烟停止：残骸不会一直冒烟到消失，那样同屏一堆残骸会糊成一片
		if smoke != null and smoke.emitting and age >= SMOKE_SECONDS:
			smoke.emitting = false
		if age >= lifetime:
			startFadeOut()
			return
		# 快到期时闪烁提示
		var left: float = lifetime - age
		if left < lifetime * BLINK_BELOW:
			var on: bool = fmod(age * BLINK_HZ, 1.0) < 0.5
			modulate.a = 1.0 if on else 0.35
	# 进度环：无论是否在回收都要刷新，否则环停在上一帧
	if ring != null:
		ring.set("progress", salvageProgress)
		ring.queue_redraw()


## 开始淡出并在结束后销毁
func startFadeOut() -> void:
	if fading:
		return
	fading = true
	# 淡出同时停掉冒烟，否则烟会留在原地不跟着消失
	if smoke != null:
		smoke.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


## 被机甲回收成功：入账 + 飘字 + 销毁。
##
## ⚠️ 钱要在这里加，而不是让机甲自己加：残骸最清楚自己值多少，
## 机甲只负责"吸"这个动作。这样"回收价"的规则只有一处（scrapValueFor）。
func collect() -> void:
	if fading:
		return
	fading = true
	if smoke != null:
		smoke.emitting = false
	# 入账：与敌人击杀同一个通路（Game.enemyRewarded 会加钱到 titleNode）
	Game.enemyRewarded.emit(scrapValue)
	RewardPopup.playAt(global_position, scrapValue)
	queue_free()
