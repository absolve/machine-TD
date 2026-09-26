extends Node2D
## 单组粒子的**基场景**脚本：只负责"点火"和"到点自毁"。
##
## 粒子的贴图 / 数量 / 速度 / 颜色**全部配在场景里**（检查器直接调），这里一行参数都不写。
##
## 用法（见 scene/fx/particle_*.tscn 四个派生场景）：
##   ① 新建继承自 `explosion_particles.tscn` 的场景
##   ② 在检查器里把 texture / amount / color / color_ramp 改成想要的样子
##   ③ 起个**能当参数传**的短名（smoke / fire / sparks / ember）
##
## 组合成一种爆炸：见 `script/fx/explosion_manage.gd` 的 BOOM_VARIANTS ——
## 那里写明"哪种爆炸挑哪几组粒子、各偏移多少"。**别把互不相干的粒子塞进同一个场景**，
## 那样谁也看不清是谁（以前的 `explosion_particles.tscn` 就是三组挤在一起）。

## 播完自动销毁。想做持续效果（引擎烟、毒雾）时设成 false，自己管生命周期。
@export var auto_free := true


func _ready() -> void:
	for p in emitters():
		if p == null:
			continue
		p.emitting = false
		p.restart()
		p.emitting = true
	if auto_free:
		await get_tree().create_timer(total_duration() + 0.1).timeout
		queue_free()


## 本场景里所有 CPUParticles2D 都算发射器 —— 派生场景想加几组都不用改脚本
func emitters() -> Array:
	var list: Array = []
	for c in get_children():
		if c is CPUParticles2D:
			list.append(c)
	return list


## 这组粒子一共要播多久（含 lifetime_randomness）。
## 组合场景（比如"大爆炸＝火焰＋烟＋火花＋余烬"）可以用它算最晚那一组什么时候结束。
func total_duration() -> float:
	var longest := 0.0
	var max_rnd := 1.0
	for p in emitters():
		if p == null:
			continue
		longest = maxf(longest, p.lifetime)
		max_rnd = maxf(max_rnd, p.lifetime_randomness + 1.0)
	return longest * max_rnd
