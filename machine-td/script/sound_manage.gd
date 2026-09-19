extends Node2D
## 全局 UI 音效（Autoload 场景，见 project.godot 的 SoundManage）。
##
## 约定：**UI 按钮的点击音只由 ui_button.gd 播一次**，
## 场景脚本不要再为同一个按钮补一遍 —— 那就会听到两声。
##
## playEffect()  —— 普通 UI 按钮点击音（coin）
## playConfirm() —— 地图内按钮的点击音（ui_confirm），比 coin 更有分量
##
## 另外这里有一道**去重闸**：极短时间内重复请求只响一次。
## 万一某个按钮被两条路径同时触发（预制体自带 + 场景脚本又调了一次），
## 也只会听到一声，不会再出现"点一下响两声"。

## 真正播出去时发出，参数是 "effect" / "confirm"。
## 用来排查"点一下响几声"这类问题：接上数一下就知道。
signal played(kind: String)

## 去重窗口（秒）。同一窗口内两条通道合计只放行一次。
## 取 30ms：真人双击间隔远大于它，但同帧 / 相邻帧的重复请求会被吃掉。
const DEDUPE_WINDOW := 0.03

## 调试开关：为 true 时每次播音都把调用栈打到控制台。
## 默认跟随 OS.is_debug_build()（编辑器里 F5 跑就是开的，导出版自动关闭）。
## 排查「一次点击响两声」时看控制台：哪两条栈都触发了，就是它们。
@export var trace_plays: bool = false

@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound

var _last_play_msec: int = -100000


func playEffect() -> void:
	_play(button_sound, "effect")


func playConfirm() -> void:
	_play(confirm_sound, "confirm")


func _play(player: AudioStreamPlayer, kind: String) -> void:
	if UserData.sfxMuted or player.stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_play_msec < int(DEDUPE_WINDOW * 1000.0):
		return
	_last_play_msec = now
	player.play()
	played.emit(kind)
	if trace_plays or OS.is_debug_build():
		_trace(kind)


# 把调用栈打出来（跳过本文件自己的帧），一眼看出是谁播的
func _trace(kind: String) -> void:
	var lines := PackedStringArray()
	lines.append("[SoundManage] play " + kind)
	for f in get_stack():
		var src: String = str(f.get("source", ""))
		if src.ends_with("sound_manage.gd"):
			continue
		lines.append("    %s:%s  %s()" % [src.get_file(), str(f.get("line", 0)), str(f.get("function", ""))])
	print("\n".join(lines))
