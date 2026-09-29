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
var sourceTower: Tower = null

@onready var aniNode = $Ani


## 让**贴图朝向**跟上飞行方向。
##
## ⚠️ 之前所有子弹都只算了 `vec = Vector2(speed, 0).rotated(angle)`，
##    也就是"飞得对，但贴图永远朝右"—— 敌人从左侧往右打还好，
##    一旦朝斜上方/斜下方开火，炮弹就是歪着平移出去，看着完全没对准目标。
##    （只有 rocketbullet.gd 自己补了 rotate(angle)，其它全漏了。）
##
## 贴图都是**朝右**画的（angle=0 = 朝右），所以直接把 angle 套到 rotation 上。
##
## ⚠️ 两个坑：
##   ① 不能写成 `_init()`：angle 是发射方在 `instantiate()` **之后**才赋值的
##      （`b.angle = (目标 - 枪口).angle()`），`_init()` 跑得太早拿不到值。
##   ② 子类重写 `_ready()` 时**不会自动执行基类 `_ready()`**，
##      所以各子类要在自己的 `_ready()` 里显式调一次这个方法。
##      （bomb.gd 是 extends Area2D、不继承本类，不需要也不应该调。）
func alignToAngle() -> void:
	rotation = angle


func _ready() -> void:
	alignToAngle()


# 命中反馈：在命中位置播一次粒子特效 + 一次音效，两者互相独立
func spawnHitEffect() -> void:
	if not is_inside_tree():
		return
	# ⚠️ 先把坐标取出来存成局部变量。调用方（gun_bullet 等）命中那一帧紧接着
	#    就 queue_free()，节点一旦离开场景树 global_position 会退化成 (0,0)，
	#    特效就跑到地图左上角了。先存下来最稳。
	var hitPos: Vector2 = global_position
	# ① 命中粒子特效 —— 走对象池，不新建不销毁（子弹一秒十几发，反复 instantiate 很浪费）
	#    variant 决定用哪种击中效果：打敌人=血肉(橙红)，打防御塔=金属(冷白)
	var variant: String = "metal" if sourceTower == null else "flesh"
	ExplosionManage.playHit(hitPos, variant)
	# ② 命中音效（SoundManage 统一管理，2D 定位，离镜头越远越轻）
	var pick: String = HIT_SOUNDS[randi() % HIT_SOUNDS.size()]
	SoundManage.playAt(pick, hitPos, -7.0, randf_range(0.92, 1.10))
