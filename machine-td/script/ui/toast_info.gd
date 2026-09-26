extends Control

## 消息提示管理器脚本
# 管理多个消息提示的显示和排列
# 负责创建、排列和移除消息提示标签


## 消息标签列表
var labelList = []

## 消息标签场景预加载
var label = preload("res://scene/toast_label.tscn")


## 初始化
func _ready() -> void:
	pass


## 显示消息提示
# 创建一个新的消息提示并添加到显示列表
# @param _str 消息文本（String）
# @param color 消息颜色（Color，默认白色）
func display(_str: String, color: Color = Color.WHITE):
	# 创建消息标签实例
	var temp = label.instantiate()
	
	# 连接移除信号
	temp.remove.connect(removeLabel)
	
	# 设置消息内容和颜色
	temp.s = _str
	temp.color = color
	
	# 添加到场景
	add_child(temp)
	
	# 添加到消息列表头部
	labelList.push_front(temp)
	
	# 调整所有消息的位置
	for i in range(labelList.size()):
		if labelList[i] != null:
			labelList[i].movePos(i)


## 移除消息标签
# 从列表中移除指定的消息标签
# @param node 要移除的消息标签节点
func removeLabel(node):
	for i in labelList:
		if i == node:
			labelList.erase(i)
			break
