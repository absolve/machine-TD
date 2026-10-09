extends Node2D
## 轰炸技能（ability "bombard"）的专属爆炸演出。
##
## 和普通爆炸（ExplosionManage.playExplosion）的区别：**大一圈、而且有扩散感** ——
##   ① 中心播一套大号爆炸帧（按技能半径放大）；
##   ② 中心再补火团 / 火花 / 余烬，一起爆一次；
##   ③ 一圈灰烟从中心**同时往外扩散**（边飞边放大），做出"冲击波扫过去"的感觉；
##   ④ 一声大爆炸音（explode_large）。
##
## 逻辑复用：粒子和爆炸帧序列都用现成的（ExplosionManage 里同一批素材），
## 这里只负责**摆位、放大、做扩散**，所以不需要重写任何伤害/判定逻辑。
##
## 用法：实例化 → 摆到爆炸中心 → `play(radius)`（radius 用来把演出按技能范围缩放）。

const BOOM_ANIM := "res://scene/explosion/explosion.tscn"
const P_SMOKE := "res://scene/fx/particle_smoke.tscn"
const P_FIRE := "res://scene/fx/particle_fire.tscn"
const P_SPARKS := "res://scene/fx/particle_sparks.tscn"
const P_EMBER := "res://scene/fx/particle_ember.tscn"
const STRIKE_SOUND := "explode_large"
## 基准半径：技能半径 = 这个值时，各缩放系数就是下面写的值
const BASE_RADIUS := 100.0

## 中心爆炸帧的缩放
@export var boomScale: float = 1.9
## 中心那几组粒子（火/火花/余烬）的缩放
@export var coreScale: float = 1.6
## 往外扩散的烟：几团、扩到多远、最后多大
@export var smokePuffs: int = 9
@export var smokeRadius: float = 120.0
@export var smokeScale: float = 2.4
## 扩散用时 / 扩散完还停留多久（然后整组消失）
@export var expandTime: float = 0.85
@export var lingerTime: float = 1.1
## 音效音量（dB）
@export var soundDb: float = -2.0


## 播一次轰炸演出。radius = 技能半径，用来自动缩放整套演出的规模。
func play(radius: float) -> void:
	var k: float = clampf(radius / BASE_RADIUS, 0.8, 2.2)
	spawnCenter(k)
	spawnSmokeRing(k)
	SoundManage.playAt(STRIKE_SOUND, global_position, soundDb)
	# 演出播完自己消失（粒子/帧动画到这时也已经播完或淡尽）
	var life: Tween = create_tween()
	life.tween_interval(expandTime + lingerTime)
	life.tween_callback(queue_free)


## 中心：大号爆炸帧 + 火/火花/余烬齐射
func spawnCenter(k: float) -> void:
	var boom: Node2D = (load(BOOM_ANIM) as PackedScene).instantiate()
	boom.scale = Vector2.ONE * boomScale * k
	add_child(boom)
	for path in [P_FIRE, P_SPARKS, P_EMBER]:
		if not ResourceLoader.exists(path):
			continue
		var fx: Node2D = (load(path) as PackedScene).instantiate()
		fx.scale = Vector2.ONE * coreScale * k
		add_child(fx)


## 一圈烟从中心往外扩散：边飞边放大，做冲击波
func spawnSmokeRing(k: float) -> void:
	if not ResourceLoader.exists(P_SMOKE) or smokePuffs <= 0:
		return
	for i in smokePuffs:
		var puff: Node2D = (load(P_SMOKE) as PackedScene).instantiate()
		puff.scale = Vector2.ONE * smokeScale * 0.3
		add_child(puff)
		var angle: float = TAU * float(i) / float(smokePuffs)
		var goal: Vector2 = Vector2.RIGHT.rotated(angle) * smokeRadius * k
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position", goal, expandTime) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector2.ONE * smokeScale * k, expandTime)
