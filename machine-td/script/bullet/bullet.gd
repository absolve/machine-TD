extends Area2D

## 命中音候选。打装甲 / 打机械 / 打硬表面分开，听起来才像"打中了不一样的东西"。
const HIT_SOUNDS: Array[String] = ["hit_metal", "hit_hard", "hit_armor"]

var vec = Vector2.ZERO # 速度
var target = null # 目标
var timer = 0
var lifetime = 0 # 存活时间
var angle = 0 # 角度
var damage = 0 # 伤害
var speed = 0 # 速度
var source_tower: Tower = null

@onready var aniNode = $ani


# 命中反馈：在命中位置播一次粒子特效 + 一次音效，两者互相独立
func spawn_hit_effect() -> void:
	if not is_inside_tree():
		return
	# ⚠️ 先把坐标取出来存成局部变量。调用方（gun_bullet 等）命中那一帧紧接着
	#    就 queue_free()，节点一旦离开场景树 global_position 会退化成 (0,0)，
	#    特效就跑到地图左上角了。先存下来最稳。
	var hit_pos: Vector2 = global_position
	# ① 命中粒子特效 —— 走对象池，不新建不销毁（子弹一秒十几发，反复 instantiate 很浪费）
	#    variant 决定用哪种击中效果：打敌人=血肉(橙红)，打防御塔=金属(冷白)
	var variant := "metal" if source_tower == null else "flesh"
	ExplosionManage.playHit(hit_pos, variant)
	# ② 命中音效（SoundManage 统一管理，2D 定位，离镜头越远越轻）
	var pick: String = HIT_SOUNDS[randi() % HIT_SOUNDS.size()]
	SoundManage.play_at(pick, hit_pos, -7.0, randf_range(0.92, 1.10))
