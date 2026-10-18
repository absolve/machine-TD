extends Node2D

## 敌人 / 防御塔头顶的血条。
##
## ★ 可见性的**唯一决策权在持有者（敌人、塔）**，血条只负责画。
##   `setValue()` / `setMax()` 只改数值，**绝不**顺手把血条点亮。
##
## 为什么必须这样拆：敌人信息面板的 `refresh()` 每帧都在读 `e.hp` 写进来，
## 如果 setter 里带"改值就显示"，那么**只要敌人被选中，血条就会被自己的面板顶出来** ——
## 玩家点谁谁冒血条，和他打没打中没关系。原来的实现就是这么写的。
##
## 命名注意：方法叫 flash()/conceal() 而不是 show()/hide() —— 后者是 CanvasItem 的
## 内建方法，同名会被 GDScript 当成非法覆盖，直接解析失败（踩过）。
##
## 敌人那边的规则：
##   · 被击中   -> flash()，强制亮一段时间，即使此刻正被选中
##   · 被选中   -> conceal()，选中期间一律不显示（攻击范围圈已经说明了他是谁）
##   · 取消选中 -> 若还在展示窗口内就重新亮起来，直到原定时间结束
##   · 计时结束 -> conceal()

## 展示时长；持有者可以用 flashFor() 逐次覆盖
@export var showSeconds: float = 3.0

@export var maxHp: int = 100:
	set(newValue):
		maxHp = newValue
		bar.max_value = newValue

## 只改数值，**不碰可见性**
@export var value: int = 100:
	set(newValue):
		value = newValue
		bar.value = newValue

@onready var bar: ProgressBar = $ProgressBar
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = showSeconds
	bar.max_value = maxHp
	bar.value = value
	bar.visible = false


## 只改数值。语义与直接赋值 `value` 相同，给调用方一个明确的名字，
## 也顺便说明"改数值不会让血条出现"。
func setValue(v: int) -> void:
	value = v


func setMax(v: int) -> void:
	maxHp = v


## 亮起来，并在 seconds 秒后自动收起
func flashFor(seconds: float) -> void:
	bar.visible = true
	timer.stop()
	timer.wait_time = maxf(0.05, seconds)
	timer.start()


## 用默认时长亮起来
func flash() -> void:
	flashFor(showSeconds)


func conceal() -> void:
	timer.stop()
	bar.visible = false


## 是否正处在"被击中"的展示窗口内（选中被取消时要据此恢复显示）
func isShowing() -> bool:
	return timer.time_left > 0.0


## 展示窗口还剩多久（取消选中时用它把剩余时间接回来）
func remaining() -> float:
	return timer.time_left


## 计时结束：收起。持有者可在计时期间用 conceal() 提前收起（例如被选中）。
func onTimerTimeout() -> void:
	bar.visible = false
