extends Node2D
## 特效总管（autoload）。爆炸和命中特效都在这里统一入口 + 统一池化。
##
## 池化思路：特效节点**建好就不再销毁**，播完只是藏起来、置 busy=false，
## 下次要用直接从池子里借。子弹一秒十几发，省掉反复 instantiate/free 的开销。
##
## ── 爆炸粒子的组织方式（v2）──
## 每个**单粒子场景**只描述一种粒子：
##   scene/fx/particle_smoke.tscn   灰烟，慢、向上飘、渐隐
##   scene/fx/particle_fire.tscn    火团，快、向上窜、橙黄
##   scene/fx/particle_sparks.tscn  火花，四射、带重力、小而亮
##   scene/fx/particle_ember.tscn   余烬，很慢、飘得久、橘红
##
## 一种爆炸 = 从上面**挑几个**摆在一起（见 BOOM_VARIANTS）。
## 想加一种爆炸：往 BOOM_VARIANTS 里加一条，写出"要哪几组粒子、各偏移多少"即可。
## 想让某种爆炸更干净：把它那一条里的粒子减掉几个 —— 不是去改粒子本身。
##
## ⚠️ 以前是"一个场景里塞三组粒子同时喷"，结果三组互相盖住，看不清是谁。
##    现在拆开了，**每种爆炸自己决定用哪几种**。

## ── 爆炸粒子 ──
const P_SMOKE := "res://scene/fx/particle_smoke.tscn"
const P_FIRE := "res://scene/fx/particle_fire.tscn"
const P_SPARKS := "res://scene/fx/particle_sparks.tscn"
const P_EMBER := "res://scene/fx/particle_ember.tscn"

## 爆炸变体：名字 -> { 单一粒子场景路径: 相对偏移 }。
## 键名可以直接当 playExplosion 的 variant 传。空字符串 = 随机挑一种。
const BOOM_VARIANTS := {
	"fire":  { P_FIRE: Vector2(0, 0), P_SMOKE: Vector2(0, -4), P_SPARKS: Vector2(0, -2) },
	"heavy": { P_FIRE: Vector2(0, 0), P_SMOKE: Vector2(0, -6), P_SPARKS: Vector2(0, -3), P_EMBER: Vector2(0, -2) },
	"spark": { P_SPARKS: Vector2(0, 0) },
	"smoke": { P_SMOKE: Vector2(0, 0), P_EMBER: Vector2(0, -3) },
}
## 随机挑的时候用哪些（"smoke" 偏持续效果，不适合当普通爆炸的随机项）
const BOOM_RANDOM_POOL: Array[String] = ["fire", "fire", "heavy", "spark"]

## ── 爆炸动画帧序列（AnimatedSprite2D + scene/explosion/explosion*.tscn）──
const BOOM_ANIMS: Array[String] = [
	"res://scene/explosion/explosion.tscn",        # 基场景（big_hit_1..11，大）
	"res://scene/explosion/explosion_small.tscn",  # 派生（boom_1..6，小）
]
## 每种爆炸变体配哪套动画。想让某变体换帧序，改这里。
const VARIANT_ANIM := {
	"fire": BOOM_ANIMS[1],
	"heavy": BOOM_ANIMS[0],
	"spark": BOOM_ANIMS[1],
	"smoke": BOOM_ANIMS[1],
}

## 爆炸音：**统一一个**，不做随机。
## 爆炸是"同一件事反复发生"，换来换去反而显得杂；
## 统一一声更干净，也让玩家对"爆了"有一致的听觉锚点。
const EXPLO_SOUND := "explode_small"

## ── 命中 ──
## 不同的击中效果就是不同的**场景**（都是 scene/fx/hit.tscn 继承出来的）。
## 想加一种：新建继承场景改导出变量，然后把路径加到这里。
const HIT_VARIANTS := {
	"default": "res://scene/fx/hit.tscn",         # 通用：暖白火花
	"metal":   "res://scene/fx/hit_metal.tscn",   # 打金属：冷白
	"flesh":   "res://scene/fx/hit_flesh.tscn",   # 打血肉：橙红，更大
	"blast":   "res://scene/fx/hit_blast.tscn",   # 爆炸型火花：火团贴图，最大最亮
}
## 每种变体各有一个池子（路径 -> Array）
var _hit_pools: Dictionary = {}
const HIT_POOL_MAX := 24
## 排查命中特效位置时打开它，会在控制台打印传入坐标和节点当前坐标
const _debug_hit_pos := false


## 播一次命中特效。variant 传 "metal" / "flesh" / "default"，留空按命中目标自动选。
func playHit(pos: Vector2, variant: String = "default") -> void:
	if not HIT_VARIANTS.has(variant):
		variant = "default"
	var fx := _acquire_hit(variant)
	if fx == null:
		return
	if _debug_hit_pos:
		print("[playHit] variant=%s 传入=%s 当前=%s busy=%s" % [
			variant, str(pos), str(fx.global_position), str(fx.busy)])
	fx.position = pos
	fx.global_position = pos
	fx.play_at(pos)


## 取一个空闲的命中特效；池子满了就抢最早那个（永不新建超过上限）
func _acquire_hit(variant: String) -> Node2D:
	var path: String = HIT_VARIANTS[variant]
	if not _hit_pools.has(variant):
		_hit_pools[variant] = []
	var pool: Array = _hit_pools[variant]
	for f in pool:
		if is_instance_valid(f) and not f.busy:
			return f
	if pool.size() >= HIT_POOL_MAX:
		var stolen = pool[0]
		pool.remove_at(0)
		if is_instance_valid(stolen):
			stolen.free()
	var fresh := (load(path) as PackedScene).instantiate()
	add_child(fresh)
	pool.append(fresh)
	return fresh


## ── 爆炸 ──
##
## variant 传 "fire" / "heavy" / "spark" / "smoke"，留空随机挑一种。
## 每种变体 = 一套动画帧序 + 一组单粒子场景（见 BOOM_VARIANTS）。
func playExplosion(pos: Vector2, variant: String = "") -> void:
	if not BOOM_VARIANTS.has(variant):
		variant = BOOM_RANDOM_POOL[randi() % BOOM_RANDOM_POOL.size()]

	# ① 爆炸动画帧
	var anim_path: String = str(VARIANT_ANIM.get(variant, BOOM_ANIMS[0]))
	if not ResourceLoader.exists(anim_path):
		anim_path = BOOM_ANIMS[0]
	var boom := (load(anim_path) as PackedScene).instantiate()
	boom.position = pos
	add_child(boom)

	# ② 粒子：这一种爆炸自己挑的那几组，各自摆好偏移
	var plan: Dictionary = BOOM_VARIANTS[variant]
	for path in plan.keys():
		if not ResourceLoader.exists(path):
			continue
		var fx := (load(path) as PackedScene).instantiate()
		fx.position = pos + (plan[path] as Vector2)
		add_child(fx)

	# ③ 音效：统一一个爆炸音，不加音高抖动 —— 每次都一样，听着才"确定"
	SoundManage.play_at(EXPLO_SOUND, pos, -4.0)
