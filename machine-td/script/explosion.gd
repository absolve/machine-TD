extends AnimatedSprite2D
## 爆炸：帧动画火球 + 冲击波环 + 径向烟 + 径向火星。
##
## ⚠️ 俯视角要点：所有扩散都是**径向**的 ——
##    没有"烟往上飘"、也没有"火星受重力下坠"，那两样是侧视角的语法。
##    这里烟和火星都在同一平面里从中心向外扩散：烟扩散慢、团大、偏灰；
##    火星扩散快、颗粒小、偏橙。
##
## 帧动画放完还要等粒子播完才 queue_free，否则粒子会被一起销毁、只剩半截。

const FIREBALL_FPS := 12.0
const FIREBALL_FRAMES := 6

## 火球整体缩放（旧素材 60x60 + scale 2 = 120px；现在 56x56 用 1.5 = 84px，小一圈）
@export var fireball_scale := 1.5
## 冲击波：扩到最大要多久、扩到多少倍
@export var shockwave_time := 0.34
@export var shockwave_scale := 2.6
## 粒子数量
@export var smoke_count := 6
@export var ember_count := 10


func _ready() -> void:
	z_index = 10
	sprite_frames = EffectAssets.get_frames("boom", FIREBALL_FRAMES, FIREBALL_FPS)
	scale = Vector2.ONE * fireball_scale

	_spawn_shockwave()
	var smoke_life := _spawn_radial(smoke_count, EffectAssets.get_smoke_texture(),
		28.0, 70.0, 0.55, 0.95, 0.45, 0.85, 2.6, Color(0.55, 0.55, 0.58, 1.0))
	var ember_life := _spawn_radial(ember_count, EffectAssets.get_ember_texture(),
		150.0, 380.0, 0.18, 0.40, 0.5, 0.9, 7.0, Color(1.0, 0.75, 0.35, 1.0))

	play("default")
	await animation_finished
	# 再等粒子自然播完，不然会被 queue_free 一起干掉、看着像被切断
	var wait := maxf(smoke_life, ember_life)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	queue_free()


# 冲击波：一个环快速放大 + 淡出，给爆炸一个"推出去了"的感觉
func _spawn_shockwave() -> void:
	var tex := EffectAssets.get_shockwave_texture()
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * 0.35
	s.modulate = Color(1.0, 0.95, 0.75, 0.9)
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (shockwave_scale / fireball_scale), shockwave_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, shockwave_time)


# 径向喷射一批粒子：从中心向四周均匀铺角度飞出，受阻力减速、缩小淡出。
# 返回这批粒子的最长存活时长，好让调用方知道要等多久。
func _spawn_radial(n: int, tex: Texture2D, spd_min: float, spd_max: float,
		life_min: float, life_max: float, size_min: float, size_max: float,
		drag: float, col: Color) -> float:
	if tex == null or n <= 0:
		return 0.0
	# 加随机相位，每次爆炸的粒子不会完全对齐
	var phase := randf() * TAU
	var longest := 0.0
	for i in n:
		var s := Sprite2D.new()
		s.texture = tex
		var ang := phase + TAU * float(i) / float(n) + randf_range(-0.25, 0.25)
		var life := randf_range(life_min, life_max)
		var sz := randf_range(size_min, size_max)
		s.scale = Vector2.ONE * sz
		s.modulate = col
		s.rotation = randf() * TAU
		add_child(s)
		longest = maxf(longest, life)
		_run_particle(s, Vector2.RIGHT.rotated(ang) * randf_range(spd_min, spd_max),
			life, sz, drag)
	return longest


# 逐帧驱动一颗粒子：速度按指数衰减（阻力），同时缩小 + 淡出
func _run_particle(s: Sprite2D, vel: Vector2, life: float, size: float, drag: float) -> void:
	var t := 0.0
	var max_life := life
	while t < max_life:
		# 父节点（或自己）可能先被释放
		if s == null or not is_instance_valid(s) or not is_inside_tree():
			return
		var dt := get_process_delta_time()
		t += dt
		var k: float = maxf(0.0, 1.0 - t / max_life)
		vel = vel * maxf(0.0, 1.0 - drag * dt)
		s.position += vel * dt
		s.scale = Vector2.ONE * (size * (0.35 + 0.65 * k))
		s.modulate.a = k
		await get_tree().process_frame
