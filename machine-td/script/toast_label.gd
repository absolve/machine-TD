extends Label

## 消息提示标签脚本
# 实现单个消息提示的显示和动画效果
# 支持淡入淡出动画，显示一段时间后自动销毁


## 移除信号（通知父节点移除自身）
signal remove

## 显示时长（秒）
var displayTime = 2

## 消息文本
var s: String: 
	set(value):
		s = value
		text = str(value)

## 边距配置
var margin = {'top': 10, 'bottom': 10, 'left': 10, 'right': 10}

## 屏幕尺寸
var screenSize: Rect2

## 消息颜色
var color: Color = Color.WHITE

## 底部偏移位置（像素）
var fixedOffsetY = 70


## 初始化
func _ready() -> void:
	# 获取屏幕尺寸
	screenSize = get_viewport_rect()
	
	# 设置消息颜色
	modulate = color
	
	# 初始化动画
	init()


## 初始化动画
# 设置初始位置并创建淡入淡出动画
func init():
	# 计算初始位置（屏幕底部居中）
	position = Vector2(screenSize.size.x / 2 - size.x / 2, screenSize.size.y - fixedOffsetY - size.y - margin.bottom / 2)
	
	# 创建补间动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0)           # 初始透明
	tween.tween_property(self, "modulate:a", 1, 0.5)         # 0.5秒淡入
	tween.tween_interval(displayTime)                        # 保持显示
	tween.tween_property(self, "modulate:a", 0, 1)           # 1秒淡出
	tween.tween_callback(removeLabel)                        # 销毁


## 移动位置
# 当有多个消息时，调整位置以避免重叠
# @param index 在消息列表中的索引
func movePos(index):
	var tween = create_tween()
	var offsetY = 0
	# 计算新的Y位置（根据索引向下偏移）
	offsetY = screenSize.size.y - fixedOffsetY - (size.y + margin.bottom / 2) * (index + 1)
	tween.tween_property(self, "position", Vector2(position.x, offsetY), 0.4)
	tween.set_trans(Tween.TRANS_SINE)


## 移除标签
# 发出移除信号并销毁自身
func removeLabel():
	remove.emit(self)
	queue_free()
