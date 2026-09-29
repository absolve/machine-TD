extends "res://script/tower/tower.gd"

const MAX_CHAIN := 4 # 闪电最多链4个敌人
const LIGHTNING_DURATION := 0.18 # 单次闪电显示时长
const flickerInterval := 0.03 # 闪电抖动重算间隔
const CHAIN_MAX_DIST := 220.0 # 链间最大距离
const CHAIN_DAMAGE_FALLOFF := 0.75 # 每次跳跃保留75%的伤害
const LIGHTNING_COLOR := Color(0.45, 0.85, 1.0, 1.0) # 闪电主色(青蓝)
## 炮塔贴图动画（`turret` 的 SpriteFrames 里有这两个动画，见 teslaCoilTower.tscn）。
## 塔身静止，动的只有两球之间的磁暴电弧 —— 所以这两套动画**共用同一批帧**，
## 区别只在播放速度：待机时电流只是缓缓跳，放电那一瞬间要快好几倍。
const ANIM_IDLE := "idle" # 待机：电流缓缓跳动
const ANIM_ATTACK := "attack" # 放电：电流急速乱窜
const ATTACK_SPEED_SCALE := 3.0 # 放电时的播放倍速（基准 18fps × 3 = 54fps 换帧）
## 击中敌人时在每个敌人身上单独播的电弧效果（独立场景）
const HIT_ARC_SCENE := preload("res://scene/fx/hit_arc.tscn")

var chainTargets: Array = [] # 当前闪电链上的敌人(按顺序)
var lightningTimer: float = 0.0 # 闪电显示剩余时间
var flickerTimer: float = 0.0 # 下次抖动重算倒计时
var jaggedPoints: PackedVector2Array = PackedVector2Array() # 缓存的折线点


func _ready() -> void:
	super._ready()
	# 炮塔动画：本塔的 turret SpriteFrames 里有 idle / attack 两个动画，
	# 帧内容一样（都是电流的几种形态），差别只在播放速度。
	# ⚠️ 必须在 super._ready() **之后** play，否则会被基类设成静态单帧。
	_playTurretAnim(ANIM_IDLE)


func _playTurretAnim(anim: String) -> void:
	if turret == null:
		return
	if not turret.sprite_frames.has_animation(anim):
		anim = ANIM_IDLE
		if not turret.sprite_frames.has_animation(anim):
			return
	if turret.animation != anim or not turret.is_playing():
		turret.play(anim)
	turret.speed_scale = ATTACK_SPEED_SCALE if anim == ANIM_ATTACK else 1.0

# func _process(delta):
# 	if lightning_timer > 0:
# 		lightning_timer -= delta
# 		flicker_timer -= delta
# 		if flicker_timer <= 0:
# 			_regenerate_jagged_points()
# 			flicker_timer = FLICKER_INTERVAL
# 		queue_redraw()

# 触发闪电: 以某个敌人为起点,收集最多MAX_CHAIN个链上敌人并显示特效
func fireLightning(initial_target):
	chainTargets = _collectChain(initial_target)
	# 攻击音：放一次电响一声。
	# 用 `arc_zap_short`（0.28 秒）—— 这是 `arc_zap` 剪出来的短版：
	# 原版整段 0.95 秒，尾巴是余响，而本塔 reload 只有 1.5 秒，
	# 整段播完会拖着"嗡——"一直响到下一次开火，听感很糊。
	# 短版是**离线剪好的音频文件**（ffmpeg 裁前 0.28 秒 + 淡出），
	# 不在代码里做限时切断 —— 音效该怎么响就该由音频文件本身决定。
	# 也不用 tower_tesla_fire：那个整段 3.44 秒，比 reload 还长。
	SoundManage.playAt("arc_zap_short", marker.global_position, -8.0, randf_range(0.92, 1.10))
	_applyChainDamage()
	lightningTimer = LIGHTNING_DURATION
	flickerTimer = 0.0
	_regenerateJaggedPoints()
	queue_redraw()

func _applyChainDamage() -> void:
	var damage: float = float(atk)
	# 命中弧线的父节点（map）。用它做 to_local 换算，比直接写 global_position 稳：
	# 万一 map 带缩放/偏移，global_position 会偏。
	var parent2d: Node2D = Game.map if Game.map is Node2D else null
	for enemy in chainTargets:
		if is_instance_valid(enemy) and enemy.has_method("hurt"):
			# 先把落点算出来，再扣血 —— hurt() 有可能把敌人打死（queue_free），
			# 之后再去读 global_position 就是读一个待释放节点的坐标。
			var hitPos: Vector2 = enemy.global_position
			enemy.hurt(max(1, int(round(damage))), self, "energy")
			# 击中效果：每个被打到的敌人身上单独播一次电弧（独立场景）。
			# 塔自己画的是"炮口 -> 敌人"那条链；这个是贴在敌人身上的迸射，两者互补。
			var arc: Node = HIT_ARC_SCENE.instantiate()
			Game.addObj(arc)
			if parent2d != null and arc.get_parent() == parent2d:
				arc.position = parent2d.to_local(hitPos)
			else:
				(arc as Node2D).global_position = hitPos
			# 命中音：链上每个敌人各响一声，音高错开，听起来像"噼里啪啦串过去"。
			# 用剪好的 0.2 秒短版 —— 原版 electric_buzz 整段 9.7 秒，
			# 一次链 4 个敌人同时播，尾巴会把整场战斗糊成一片电流噪声。
			SoundManage.playAt("electric_buzz_short", hitPos, -12.0, randf_range(0.85, 1.25))
		damage *= CHAIN_DAMAGE_FALLOFF
	
## 这个"目标"能不能当 Area2D 用。
##
## ★ 为什么需要这道闸：敌人场景（如 miniTank.tscn）的**根节点是 PathFollow2D**，
## 真正的 Area2D 是它的子节点 `enemy`。跑关卡时路径根节点有机会混进 `target` 列表，
## 而基类签名是 `can_target(area: Area2D)` —— 直接把 PathFollow2D 传进去，
## GDScript 会**抛类型错**（不是返回 false），整条链就废了：
## 闪电画不出来、命中弧线一个都生不出来。
## 加一道类型闸，凡是进不了 can_target 的东西直接当"不是目标"跳过。
func _isAreaTarget(t) -> bool:
	return t is Area2D


# 贪心收集链上敌人: 从首个敌人开始,每次找最近的未使用目标
func _collectChain(first) -> Array:
	if not is_instance_valid(first) or not _isAreaTarget(first) or not canTarget(first):
		return []
	var result: Array = [first]
	var used: Dictionary = {first: true}
	var current = first
	while result.size() < MAX_CHAIN:
		var next = null
		var bestDist = CHAIN_MAX_DIST
		for t in target:
			if used.has(t) or not is_instance_valid(t) or not _isAreaTarget(t) or not canTarget(t):
				continue
			var d = t.global_position.distance_to(current.global_position)
			if d < bestDist:
				bestDist = d
				next = t
		if next == null:
			break
		result.append(next)
		used[next] = true
		current = next
	return result

# 重新生成抖动折线点: 炮口 -> 敌人1 -> 敌人2 -> ... 
func _regenerateJaggedPoints():
	jaggedPoints.clear()
	if chainTargets.is_empty():
		return
	var start = to_local(marker.global_position)
	jaggedPoints.append(start)
	for enemy in chainTargets:
		if !is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		var seg = _generateSegment(start, end, 6, 18.0)
		for p in seg:
			jaggedPoints.append(p)
		jaggedPoints.append(end)
		start = end

# 在 from->to 之间生成抖动中点(不含首尾)
func _generateSegment(from: Vector2, to: Vector2, segments: int, jitter: float) -> Array:
	var arr: Array = []
	var dir = to - from
	if dir.length() < 1.0:
		return arr
	var normal = dir.normalized()
	var perp = Vector2(-normal.y, normal.x)
	for i in range(1, segments):
		var t = float(i) / segments
		var base1 = from + dir * t
		var offset = perp * randf_range(-jitter, jitter)
		arr.append(base1 + offset)
	return arr

func _drawLightningPath(points: PackedVector2Array, base_color: Color, max_width: float, min_width: float, outer_alpha: float, inner_alpha: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var chainIndex = i / 6
		var chainCount = maxi(1, int(ceil(float(points.size() - 1) / 6.0)))
		var chainRatio = float(chainIndex) / float(max(chainCount - 1, 1))
		var chainScale = lerp(1.0, 0.42, chainRatio)
		var segmentProgress: float = float(i % 6) / 5.0
		var width = lerp(max_width, min_width, segmentProgress) * chainScale
		var alpha = lerp(outer_alpha, 0.2, segmentProgress)
		var start = points[i]
		var end = points[i + 1]
		draw_line(start, end, Color(base_color.r, base_color.g, base_color.b, alpha), width * 1.5)
		draw_line(start, end, Color(base_color.r, base_color.g, base_color.b, inner_alpha), max(width * 0.45, 1.0))
		draw_line(start, end, Color(1.0, 1.0, 1.0, clamp(alpha * 0.9, 0.0, 1.0)), max(width * 0.18, 0.6))



func _onRadarAreaEntered(area: Area2D) -> void:
	addTarget(area)


func _onRadarAreaExited(area: Area2D) -> void:
	target.erase(area)


func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	var t = getTarget()
	if t and canShot:
		fireLightning(t)
		canShot = false
		delayTimer.start()

	if lightningTimer > 0:
		lightningTimer -= _delta
		flickerTimer -= _delta
		if flickerTimer <= 0:
			_regenerateJaggedPoints()
			flickerTimer = flickerInterval
		queue_redraw()
	# 电流形态：静着也一直在跳，放电那一小段切到急速版
	if lightningTimer > 0.0:
		_playTurretAnim(ANIM_ATTACK)
	else:
		_playTurretAnim(ANIM_IDLE)


## 切炮塔动画。名字不存在就退回 idle。
## ⚠️ 两个坑：
##   1. `AnimatedSprite2D.animation` 的**默认名就是 "idle"**（不是空串）。
##      所以"名字一样就跳过 play()"会漏掉最常见的情况 —— 建塔时名字已经是 idle、
##      但动画根本没在跑，表现就是**电流一动不动**。必须同时查 is_playing()。
##   2. 重复 `play()` 同一个动画会把帧数清零，电流会一顿一顿的，
##      所以"确实在播同一个动画"时要跳过。


func _draw():
	super._draw()
	if lightningTimer <= 0 or jaggedPoints.size() < 2:
		return
	_drawLightningPath(jaggedPoints, LIGHTNING_COLOR, 13.0, 1.0, 0.25, 0.75)
	# 每个击中点画一个光晕
	for enemy in chainTargets:
		if !is_instance_valid(enemy):
			continue
		var p = to_local(enemy.global_position)
		draw_circle(p, 10.0, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(p, 5.0, Color(LIGHTNING_COLOR.r, LIGHTNING_COLOR.g, LIGHTNING_COLOR.b, 0.8))
