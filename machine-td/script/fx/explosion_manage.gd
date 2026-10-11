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
##
## ⚠️ 这里**同时是"合法变体名"的白名单** —— playExplosion 开头的
##    `if not BOOM_VARIANTS.has(variant)` 会把不在表里的名字当成无效值、随机换成别的。
##    所以新增一套纯帧动画的爆炸（不需要粒子）时，**也必须在这里登记**，
##    哪怕对应的值是个空字典 `{}`（表示这套爆炸只播帧、不叠粒子）。
const BOOM_VARIANTS := {
	"fire":  { P_FIRE: Vector2(0, 0), P_SMOKE: Vector2(0, -4), P_SPARKS: Vector2(0, -2) },
	"heavy": { P_FIRE: Vector2(0, 0), P_SMOKE: Vector2(0, -6), P_SPARKS: Vector2(0, -3), P_EMBER: Vector2(0, -2) },
	"spark": { P_SPARKS: Vector2(0, 0) },
	"smoke": { P_SMOKE: Vector2(0, 0), P_EMBER: Vector2(0, -3) },
	# 下面三套是 VFX Free Pack 的逐帧素材：**纯帧动画、不叠粒子**（用户要求可以不加粒子）
	"puff": {},
	"blast_big": {},
	"ring": {},
}
## 随机挑的时候用哪些（"smoke" 偏持续效果，不适合当普通爆炸的随机项）
const BOOM_RANDOM_POOL: Array[String] = ["fire", "fire", "heavy", "spark"]

## ── 爆炸动画帧序列（AnimatedSprite2D + scene/explosion/explosion*.tscn）──
## 后三套来自 `VFX Free Pack` 的 60fps 逐帧素材（每帧一张 PNG，
## 与项目既有做法一致；**不带粒子**，就是纯帧动画）。
const BOOM_ANIMS: Array[String] = [
	"res://scene/explosion/explosion.tscn", # 基场景（big_hit_1..11，大）
	"res://scene/explosion/explosion_small.tscn", # 派生（boom_1..6，小）
	"res://scene/explosion/explosion_puffstar.tscn", # 烟团+星星（80 帧，108px）
	"res://scene/explosion/explosion_big2.tscn", # 大爆炸（60 帧，517px 缩到 0.42）
	"res://scene/explosion/explosion_ring.tscn", # 环形扩散（60 帧，355px 缩到 0.60）
]
## 每种爆炸变体配哪套动画。想让某变体换帧序，改这里。
const VARIANT_ANIM := {
	"fire": BOOM_ANIMS[1],
	"heavy": BOOM_ANIMS[0],
	"spark": BOOM_ANIMS[1],
	"smoke": BOOM_ANIMS[1],
	# 新增的三套：各占一个变体，方便按需指定；不指定时会走下面的随机池。
	"puff": BOOM_ANIMS[2],
	"blast_big": BOOM_ANIMS[3],
	"ring": BOOM_ANIMS[4],
}

## 爆炸音：**统一一个**，不做随机。
## 爆炸是"同一件事反复发生"，换来换去反而显得杂；
## 统一一声更干净，也让玩家对"爆了"有一致的听觉锚点。
const EXPLO_SOUND := "explode_small"

## ── 残骸（见 feature_design.md §十一）──
## 残骸由这里生成，和爆炸/命中特效同一个道理：挂在 autoload 下，
## **换关卡时会跟着一起被清掉**，不会在下一关的同一坐标冒出一坨上一关的尸体。
## （残骸本身不做池化，理由见 script/fx/wreckage.gd 的头部注释。）
const WRECKAGE_SCENE := "res://scene/fx/wreckage.tscn"


## 在 pos 生成一坨敌人残骸。
##   pos    敌人死亡瞬间的**世界坐标**（必须在其 freeSelf() 之前取好）
##   tex    敌人的身体贴图（哪一帧都行）
##   reward 该敌人的击杀金币，用来算回收价
##   life   存活时长（秒）
## 返回生成出来的残骸节点（探针用得上），生成失败返回 null。
func spawnWreckage(pos: Vector2, tex: Texture2D, reward: int, life: float) -> Node:
	if not ResourceLoader.exists(WRECKAGE_SCENE):
		push_warning("wreckage scene missing: " + WRECKAGE_SCENE)
		return null
	var w: Node2D = (load(WRECKAGE_SCENE) as PackedScene).instantiate()
	# 与飘字同款：autoload 是 /root 的直接子节点，世界坐标直接当 global_position 用
	w.global_position = pos
	add_child(w)
	# setup 放在 add_child **之后**：这时节点已在树里、_ready 已经跑过，
	# wreckage.gd 的 setup 才能既写贴图又不必担心组还没注册
	w.call("setup", tex, reward, life)
	return w

## ── 命中 ──
## 不同的击中效果就是不同的**场景**（都是 scene/fx/hit.tscn 继承出来的）。
## 想加一种：新建继承场景改导出变量，然后把路径加到这里。
const HIT_VARIANTS := {
	"default": "res://scene/fx/hit.tscn", # 通用：暖白火花
	"metal":   "res://scene/fx/hit_metal.tscn", # 打金属：冷白
	"flesh":   "res://scene/fx/hit_flesh.tscn", # 打血肉：橙红，更大
	"blast":   "res://scene/fx/hit_blast.tscn", # 爆炸型火花：火团贴图，最大最亮
}
## 每种变体各有一个池子（路径 -> Array）
var hitPools: Dictionary = {}
const HIT_POOL_MAX := 24
## 排查命中特效位置时打开它，会在控制台打印传入坐标和节点当前坐标
const _debug_hit_pos := false


## 播一次命中特效。variant 传 "metal" / "flesh" / "default"，留空按命中目标自动选。
func playHit(pos: Vector2, variant: String = "default") -> void:
	if not HIT_VARIANTS.has(variant):
		variant = "default"
	var fx: Node2D = acquireHit(variant, pos)
	if fx == null:
		return
	if _debug_hit_pos:
		print("[playHit] variant=%s 传入=%s 当前=%s busy=%s" % [
			variant, str(pos), str(fx.global_position), str(fx.busy)])
	# 定位**只**交给 playAt()，这里不要再单独写 fx.position / fx.global_position。
	# 同一帧里把节点坐标改两次，中间态就可能被画出来。
	fx.playAt(pos)


## 取一个空闲的命中特效；池子满了就抢最早那个（永不新建超过上限）。
##
## ★ `play_pos` 必须在新建节点**入树之前**就传进来。
##   玩家实测的 bug（"亮色小火花往左上角飞"）只在**池子还是空的、第一次初始化**时出现：
##   冷启动新建的节点出生在 (0,0)，如果先 `add_child()` 再定位，它就有机会在**地图原点**
##   ——也就是画面左上方向——被画出来一次；池子里有节点之后直接复用，就不再发生。
##   把定位提前到入树之前，新建的节点**从一开始就在命中点**，这一帧中间态根本不存在。
func acquireHit(variant: String, play_pos: Vector2) -> Node2D:
	var path: String = HIT_VARIANTS[variant]
	if not hitPools.has(variant):
		hitPools[variant] = []
	var pool: Array = hitPools[variant]
	for f in pool:
		if is_instance_valid(f) and not f.busy:
			return f
	if pool.size() >= HIT_POOL_MAX:
		var stolen = pool[0]
		pool.remove_at(0)
		if is_instance_valid(stolen):
			stolen.free()
	var fresh: Node = (load(path) as PackedScene).instantiate()
	# 入树前先摆好位置：节点从没在 (0,0) 存在过，也就没机会被画在那
	(fresh as Node2D).position = play_pos
	(fresh as Node2D).global_position = play_pos
	add_child(fresh)
	pool.append(fresh)
	return fresh


## ── 爆炸 ──
##
## variant 传 "fire" / "heavy" / "spark" / "smoke" / "puff" / "blast_big" / "ring"，
## 留空随机挑一种。每种变体 = 一套动画帧序 +（可选的）一组单粒子场景。
##
## `puff` / `blast_big` / `ring` 是 VFX Free Pack 的逐帧素材，**只播帧、不叠粒子**
## （在 BOOM_VARIANTS 里登记成空字典，见那里的注释 —— 不登记会被当成无效名字换掉）。
func playExplosion(pos: Vector2, variant: String = "") -> void:
	if not BOOM_VARIANTS.has(variant):
		variant = BOOM_RANDOM_POOL[randi() % BOOM_RANDOM_POOL.size()]

	# ① 爆炸动画帧
	var animPath: String = str(VARIANT_ANIM.get(variant, BOOM_ANIMS[0]))
	if not ResourceLoader.exists(animPath):
		animPath = BOOM_ANIMS[0]
	var boom: Node = (load(animPath) as PackedScene).instantiate()
	boom.position = pos
	add_child(boom)

	# ② 粒子：这一种爆炸自己挑的那几组，各自摆好偏移
	var plan: Dictionary = BOOM_VARIANTS[variant]
	for path in plan.keys():
		if not ResourceLoader.exists(path):
			continue
		var fx: Node = (load(path) as PackedScene).instantiate()
		fx.position = pos + (plan[path] as Vector2)
		add_child(fx)

	# ③ 音效：统一一个爆炸音，不加音高抖动 —— 每次都一样，听着才"确定"
	SoundManage.playAt(EXPLO_SOUND, pos, -4.0)
