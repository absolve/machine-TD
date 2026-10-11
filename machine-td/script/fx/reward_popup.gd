extends Node2D
## 击杀金币飘字总管（autoload，见 project.godot 的 [autoload]）。
##
## ★ 为什么是 autoload 而不是挂在 map 下：与 ExplosionManage 同一个理由 ——
##   飘字要在一个**独立的常驻场景**里池化。挂在 map 下的话，换关卡时整个池子跟着
##   场景一起释放，下一关又得从头新建，"省掉反复 instantiate" 的意义就没了。
##
## ★ 为什么走 global_position 而不是 position：autoload 是 /root 的直接子节点，
##   地图相机（CanvasLayer 之外的 Camera2D）会作用在所有世界坐标节点上，
##   所以敌人传进来的世界坐标直接当 global_position 用就对得上。
##
## 池化思路与 ExplosionManage.hitPools 一致：建好就不再销毁，播完置 busy=false
## 留着复用；池满就抢最早那个。

const ITEM_SCENE := "res://scene/fx/reward_popup_item.tscn"
## 同屏飘字上限。一波几十只敌人同时倒下的极端情况也不会超过这个数。
const POOL_MAX: int = 40

## 排查用：打开后每次播放都打印坐标
const _debug_popup := false

var _pool: Array = []


func _ready() -> void:
	# autoload 自己不该被暂停影响：暂停时打出来的飘字也要正常播完，
	# 否则会停在半空（或一直 busy，把池子占死）。
	process_mode = Node.PROCESS_MODE_ALWAYS


## 在 pos 弹一个 "+amount"。amount <= 0 时直接不弹（没收益就别刷数字）。
func playAt(pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var item: Node2D = acquire(pos)
	if item == null:
		return
	if _debug_popup:
		print("[RewardPopup] amount=%d pos=%s node=%s" % [amount, str(pos), str(item.global_position)])
	item.playAt(pos, amount)


## 取一个空闲飘字项；池满就抢最早那个。
##
## ★ `play_pos` 必须在新建节点**入树之前**传进来。
##   冷启动时新建的节点出生在 (0,0)，若先 add_child 再定位，它有机会在**世界原点**
##   （画面左上方向）被画出一帧。命中特效那边正是踩过这个坑
##   （见 explosion_manage.gd::acquireHit 的注释），这里沿用同一个做法。
func acquire(play_pos: Vector2) -> Node2D:
	for it in _pool:
		if is_instance_valid(it) and not it.busy:
			return it
	if _pool.size() >= POOL_MAX:
		var stolen = _pool[0]
		_pool.remove_at(0)
		if is_instance_valid(stolen):
			stolen.queue_free()
	var fresh: Node = (load(ITEM_SCENE) as PackedScene).instantiate()
	# 入树前先摆好位置：节点从没在 (0,0) 存在过，也就没机会被画在那
	(fresh as Node2D).global_position = play_pos
	add_child(fresh)
	_pool.append(fresh)
	return fresh


## 池子当前节点数（探针用来确认复用生效、没有泄漏）
func poolSize() -> int:
	var n: int = 0
	for it in _pool:
		if is_instance_valid(it):
			n += 1
	return n
