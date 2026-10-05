extends Node2D
class_name AirRouteHint
## 空中航线提示动画（战斗飞机那条"看不见的航线"的专用提示）。
##
## 为什么需要它：地面路线都铺了传送带，玩家一眼看得出敌人往哪走；而战斗飞机走的
## 空中航线**在场景里什么都没铺** —— 不给提示，玩家只看到"天上突然冒出一架飞机"。
## 所以敌机第一次从这条航线生成时，把航线画出来提醒一次（哪几条路线需要提示由
## 关卡数据声明，见 base_level.gd 的 hintRoutes / StageData.getHintRoutes）。
##
## 表现：把航线切成**一截截虚线**，沿敌人前进方向**逐段点亮** —— 正在点亮的那一截
## 用更粗的白亮色当"头"，已经点亮的保持警示黄，还没点亮的只留一层很淡的底影；
## 整条亮完停留一会儿，再整体淡出，节点自己 queue_free()。
##
## 为什么是虚线而不是一条实线：实线 + 流光看起来像"一条路面"；虚线一段段亮起来
## 更像"路线被标出来"，方向也更清楚。虚线就在 _draw() 里画（一截 = 一条 draw_line），
## **不写 shader、不依赖任何贴图**；长度/间隔/线宽/配色全部 @export，在场景里调。

## 底衬淡入 / 逐段点亮 / 停留 / 淡出 的时长（秒）
const FADE_IN_TIME := 0.5
const FILL_TIME := 1.4
const HOLD_TIME := 1.2
const FADE_TIME := 0.7
## 底衬（暗色描边）最终不透明度：让虚线在亮色地面上也能看清
const BACK_ALPHA := 0.5

## 一截虚线的长度 / 间隔 / 线宽（像素）
@export var dashLength: float = 26.0
@export var dashGap: float = 20.0
@export var dashWidth: float = 8.0
## 正在点亮那一截的线宽（比普通截更粗，方向一眼可见）与颜色
@export var headWidth: float = 14.0
@export var headColor: Color = Color(1, 0.98, 0.9, 1)
## 已点亮 / 还没点亮 的虚线颜色
@export var litColor: Color = Color(1, 0.776, 0.102, 1)
@export var unlitColor: Color = Color(1, 0.776, 0.102, 0.14)

@onready var backLine: Line2D = $Back

## 航线折线（本节点局部坐标，由 base_level 换算好传进来）
var routePoints: PackedVector2Array = PackedVector2Array()
## 每一截虚线的两个端点：第 i 截 = dashPoints[2i] → dashPoints[2i+1]
var dashPoints: PackedVector2Array = PackedVector2Array()
## 一截 = 2 个点，单独存一份免得每次除
var dashCount: int = 0
## 已经点亮了几截
var litCount: int = 0


## 播放一次提示。points 用本节点的局部坐标（base_level 已经换算过）。
func play(points: PackedVector2Array) -> void:
	routePoints = points
	backLine.points = routePoints
	_buildDashes()
	litCount = 0
	queue_redraw()
	_run()


## 把折线按弧长切成"长 dashLength、隔 dashGap"的虚线
func _buildDashes() -> void:
	dashPoints = PackedVector2Array()
	dashCount = 0
	if routePoints.size() < 2 or dashLength <= 0.0:
		return
	var total: float = _routeLength()
	var period: float = dashLength + dashGap
	var at: float = 0.0
	while at < total:
		dashPoints.append(_pointAt(at))
		dashPoints.append(_pointAt(minf(at + dashLength, total)))
		at += period
	@warning_ignore("integer_division")
	dashCount = dashPoints.size() / 2


## 整条航线的弧长
func _routeLength() -> float:
	var total: float = 0.0
	for i in routePoints.size() - 1:
		total += routePoints[i].distance_to(routePoints[i + 1])
	return total


## 取航线上弧长 atLen 处的点（折线内线性插值）
func _pointAt(atLen: float) -> Vector2:
	var acc: float = 0.0
	for i in routePoints.size() - 1:
		var seg: float = routePoints[i].distance_to(routePoints[i + 1])
		if acc + seg >= atLen or i == routePoints.size() - 2:
			var k: float = 0.0 if seg <= 0.0 else clampf((atLen - acc) / seg, 0.0, 1.0)
			return routePoints[i].lerp(routePoints[i + 1], k)
		acc += seg
	return routePoints[routePoints.size() - 1]


## 底衬淡入 → 逐段点亮 → 停留 → 淡出，最后自己销毁
func _run() -> void:
	modulate.a = 1.0
	backLine.default_color.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(backLine, "default_color:a", BACK_ALPHA, FADE_IN_TIME)
	tween.tween_method(_setLitProgress, 0.0, 1.0, FILL_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


## 点亮进度 0 → 1：只有"又亮了一截"时才重绘，不用每帧重画
func _setLitProgress(progress: float) -> void:
	var n: int = int(round(progress * float(dashCount)))
	if n == litCount:
		return
	litCount = n
	queue_redraw()


func _draw() -> void:
	var allDone: bool = litCount >= dashCount
	for i in dashCount:
		var from: Vector2 = dashPoints[i * 2]
		var to: Vector2 = dashPoints[i * 2 + 1]
		if allDone or i < litCount - 1:
			draw_line(from, to, litColor, dashWidth)
		elif i == litCount - 1:
			draw_line(from, to, headColor, headWidth)
		else:
			draw_line(from, to, unlitColor, dashWidth)
