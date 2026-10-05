extends Node2D
## 全局音频（Autoload 场景，见 project.godot 的 SoundManage）。
##
## 四块功能：
##   ① UI 点击音  —— playEffect() / playConfirm()。**只由按钮预制体自己调**（见下面的约定）。
##   ② 通用音效    —— play("hit_metal") 按名字播 sound/sfx/ 下的文件。
##   ③ 循环音      —— start_loop("tesla", "tower_tesla_hum") / stop_loop("tesla")。
##   ④ 背景音乐    —— play_bgm("bgm_07_heaven_pad") / stop_bgm()，走 Bg 总线。
##
## 用法：
##   SoundManage.play("hit_metal") # 最简
##   SoundManage.play("explode_small", -6.0) # 第二个参数是音量(dB)
##   SoundManage.play("tower_mg_fire", 0.0, randf_range(0.96, 1.04)) # 第三个是音高
##   SoundManage.play_varied(["hit_hard", "hit_armor"]) # 从几个里随机挑，带轻微音高抖动
##   SoundManage.play_at("explode_large", global_position) # 按世界坐标摆左右声像
##   SoundManage.play_bgm("bgm_07_heaven_pad") # 背景音乐（同名重复调用不会重头开始）
##
## 名字就是 sound/sfx/ 下的文件名（不带 .ogg）。加新音效直接把 ogg 丢进去就能用，
## 这里一行都不用改。
##
## 通用音效内部用**播放器池**：同时响十几个不会互相打断，也不会每次 new 一个节点。
##
## 约定：**UI 按钮的点击音只由 ui_button.gd 播一次**，
## 场景脚本不要再为同一个按钮补一遍 —— 那就会听到两声。详见 sound/CREDITS.md。

## 真正播出去时发出，参数是 "effect" / "confirm"。
## 用来排查"点一下响几声"这类问题：接上数一下就知道。
signal played(kind: String)

## 去重窗口（秒）。同一窗口内两条通道合计只放行一次。
## 取 30ms：真人双击间隔远大于它，但同帧 / 相邻帧的重复请求会被吃掉。
const DEDUPE_WINDOW := 0.03

## 通用音效所在目录（用文件名当 key）
const SFX_DIR := "res://sound/sfx/"

## 调试开关：为 true 时每次播音都把调用栈打到控制台。
## 默认跟随 OS.is_debug_build()（编辑器里 F5 跑就是开的，导出版自动关闭）。
## 排查「一次点击响两声」时看控制台：哪两条栈都触发了，就是它们。
#@export var trace_plays: bool = false

## 音效播放器池上限。池子满了就临时再加一个（很少发生）
@export var sfxPoolSize: int = 16
## play_at 用的 2D 播放器池上限
@export var posPoolSize: int = 8

## 悬停音的节流（毫秒）。鼠标扫过一排按钮时会连续触发 mouse_entered，
## 取 60ms 让它是"清脆的一下"，而不是哒哒哒响成一片。
## 悬停音的节流窗口。
## ★ 必须**大于等于** ui_hover 音效本身的长度（现在 0.09 秒），
##   否则快速扫过一排按钮时，前一声还没播完就叠上下一声，
##   听起来是"哒哒哒"而不是干净的一声"滴"。
const HOVER_GUARD_MSEC := 95

@onready var buttonSound: AudioStreamPlayer = $ButtonSound
@onready var confirmSound: AudioStreamPlayer = $ConfirmSound
@onready var hoverSound: AudioStreamPlayer = $HoverSound

var _lastPlayMsec: int = -100000
## 悬停音单独计时。
## ⚠️ 不能和 _last_play_msec 共用 —— 那样"鼠标 hover 完立刻点击"会把点击吃掉。
var _lastHoverMsec: int = -100000

## 通用音效的播放器池
var _sfxPool: Array[AudioStreamPlayer] = []
## play_at 用的 2D 播放器池
var _posPool: Array[AudioStreamPlayer2D] = []
## 名字 -> AudioStream；查不到也缓存（存 null），避免每次都去 exists()
var _sfxCache: Dictionary = {}
## 循环音：key -> 播放器
var _loops: Dictionary = {}

## 背景音乐所在目录（和 sfx/ 分开：bgm 是整首长音，走 Bg 总线，不受音效静音影响）
const BGM_DIR := "res://sound/bgm/"

## 背景音乐专用播放器。**常驻一个**，切曲就是换 stream，
## 不走 _sfx_pool —— 音效池会被 stop_all() 清掉，音乐会跟着断。
@onready var bgmPlayer: AudioStreamPlayer = $Bgm

## 当前在播的曲名（文件名去扩展名）。空 = 没在播。
## 用它做去重：同一首重复调用不必重头开始。
var _bgmCurrent: String = ""
## BGM 音量（dB）。素材本身已归一到 -16 LUFS，所以默认不再衰减。
var _bgmVolumeDb: float = 0.0
## 歌名 -> AudioStream 缓存（查不到也缓存 null，避免反复打文件系统）
var _bgmCache: Dictionary = {}


# ============================================================
# ① UI 点击音
# ============================================================

func playEffect() -> void:
	_play(buttonSound, "effect")


func playConfirm() -> void:
	_play(confirmSound, "confirm")


## 鼠标移上按钮的音（sfx/ui_hover.ogg）。
## 比点击音轻，所以不走去重闸、也不打调用栈 —— 但有自己的节流。
func playHover() -> void:
	if UserData.sfxMuted or hoverSound.stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _lastHoverMsec < HOVER_GUARD_MSEC:
		return
	_lastHoverMsec = now
	hoverSound.play()


func _play(player: AudioStreamPlayer, kind: String) -> void:
	if UserData.sfxMuted or player.stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _lastPlayMsec < int(DEDUPE_WINDOW * 1000.0):
		return
	_lastPlayMsec = now
	player.play()
	played.emit(kind)
	#if trace_plays or OS.is_debug_build():
		#_trace(kind)


# 把调用栈打出来（跳过本文件自己的帧），一眼看出是谁播的
#func _trace(kind: String) -> void:
	#var lines := PackedStringArray()
	#lines.append("[SoundManage] play " + kind)
	#for f in get_stack():
		#var src: String = str(f.get("source", ""))
		#if src.ends_with("sound_manage.gd"):
			#continue
		#lines.append("    %s:%s  %s()" % [src.get_file(), str(f.get("line", 0)), str(f.get("function", ""))])
	#print("\n".join(lines))


# ============================================================
# ② 通用音效（按名字播 sound/sfx/ 下的文件）
# ============================================================

## 播一个音效。sound 是文件名（不带扩展名），volume_db 是音量，pitch_scale 是音高。
## 返回正在播的播放器（方便调用方自己停），静音 / 找不到文件时返回 null。
func play(sound: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if UserData.sfxMuted:
		return null
	var stream: AudioStream = _getSfx(sound)
	if stream == null:
		return null
	var p: AudioStreamPlayer = _acquire()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()
	return p


## 从几个音效里随机挑一个播，并给一点音高抖动 —— 连续开火 / 连续命中时不会听腻。
func playVaried(sounds: Array, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> AudioStreamPlayer:
	if sounds.is_empty():
		return null
	var pick: String = str(sounds[randi() % sounds.size()])
	var jitter: float = 1.0 if pitch_jitter <= 0.0 else randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	return play(pick, volume_db, jitter)


## 按世界坐标播（左右声像 + 距离衰减）。
## 听者 = map 相机上的 AudioListener2D（`scene/custom_camera.tscn`，跟着可视区中心走），
## 所以塔开火 / 命中 / 爆炸这些声音才有左右方位和远近。
## 兜底：万一以后有场景既没听者也没相机，就退化成普通播放 ——
## 宁可没有声像，也不要“声音位置算错、听起来全在一边”。
func playAt(
	sound: String,
	world_pos: Vector2,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	max_distance: float = 1400.0
) -> Node:
	if UserData.sfxMuted:
		return null
	var stream: AudioStream = _getSfx(sound)
	if stream == null:
		return null
	if not _hasListener():
		return play(sound, volume_db, pitch_scale)
	var p: AudioStreamPlayer2D = _acquire2d()
	p.stream = stream
	p.global_position = world_pos
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.max_distance = max_distance
	p.play()
	return p


## 这个名字有没有对应文件（想在代码里先判断时用）
## 按名字取音频流（不播放）。给"自己持有播放器"的场景用，比如爆炸三件套里的 sound 节点。
func getStreamFor(sound: String) -> AudioStream:
	return _getSfx(sound)


func hasSfx(sound: String) -> bool:
	return _getSfx(sound) != null


# ============================================================
# ③ 循环音（持续音，比如特斯拉嗡鸣）
# ============================================================

## 开一个循环音。同一个 key 重复调用只当一次（已经在响就什么都不做）。
func startLoop(key: String, sound: String, volume_db: float = 0.0) -> void:
	if UserData.sfxMuted or _loops.has(key):
		return
	var stream: AudioStream = _getSfx(sound)
	if stream == null:
		return
	# ogg 靠 loop 属性无缝循环；不勾的话播完就停
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Sfx"
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[key] = p


func stopLoop(key: String) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]
	_loops.erase(key)
	if is_instance_valid(p):
		p.stop()
		p.queue_free()


func stopAllLoops() -> void:
	for key in _loops.keys():
		stopLoop(key)


# ============================================================
# ④ 背景音乐（走 Bg 总线，整首无缝循环）
# ============================================================
#
# 和 sfx 的三点区别：
#   · 走 **Bg** 总线 —— 顶栏的 ♪ 开关和设置里的"背景音"滑条控的都是它
#   · 用常驻的 bgm_player，换曲只换 stream，不会被 stop_all() 掐掉
#   · 同名重复调用直接返回，不会把正在放的曲子重头开始
#
# 用法：
#   SoundManage.play_bgm("bgm_07_heaven_pad") # 名字 = sound/bgm/ 下的文件名
#   SoundManage.stop_bgm()
#   if SoundManage.current_bgm() == "bgm_08_lunar_amb": ...

## 放一首 BGM。参数是 sound/bgm/ 下的文件名（不带 .ogg）。
## 同一首且正在播 → 什么都不做（所以在"每次点开始"里无脑调也安全）。
func playBgm(sound: String, volume_db: float = 0.0) -> void:
	if sound.is_empty():
		return
	# ★ 已经在放同一首就别重头开始 —— 暂停后继续、重开关卡都会走到这里
	if _bgmCurrent == sound and bgmPlayer.playing:
		return
	var stream: AudioStream = _getBgm(sound)
	if stream == null:
		push_warning("SoundManage.play_bgm: 找不到 sound/bgm/%s.ogg" % sound)
		stopBgm()
		return
	_bgmCurrent = sound
	if stream is AudioStreamOggVorbis:
		# 兜底：.import 里的 loop 已设 true，但顺手再置一次，
		# 这样以后直接丢一首新 ogg 进 sound/bgm/ 也能循环，不用管导入参数。
		(stream as AudioStreamOggVorbis).loop = true
	bgmPlayer.stream = stream
	bgmPlayer.volume_db = volume_db
	# 暂停游戏时（get_tree().paused = true）音乐要继续放，所以不受 pause 影响
	bgmPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	bgmPlayer.play()


## 停掉 BGM。stop_bgm(false) 会保留 _bgm_current，下次 play_bgm 同一首仍会重放。
func stopBgm(clear_current: bool = true) -> void:
	bgmPlayer.stop()
	bgmPlayer.stream = null
	if clear_current:
		_bgmCurrent = ""


## 当前在播的曲名（空 = 没在播）
func currentBgm() -> String:
	return _bgmCurrent


## BGM 是否正在响
func isBgmPlaying() -> bool:
	return bgmPlayer != null and bgmPlayer.playing


## 临时压低/恢复 BGM（比如想给剧情语音让路）
func duckBgm(volume_db: float) -> void:
	bgmPlayer.volume_db = volume_db


## 当前 BGM 的播放进度（秒），没在播返回 0
func bgmPlaybackPosition() -> float:
	return bgmPlayer.get_playback_position() if isBgmPlaying() else 0.0


# ============================================================
# 通用控制
# ============================================================

## 停掉所有正在响的音效（切场景 / 关面板时用）
func stopAll() -> void:
	for p in _sfxPool:
		if is_instance_valid(p):
			p.stop()
	for p in _posPool:
		if is_instance_valid(p):
			p.stop()


## 回收空闲播放器，把节点释放掉
func trimPools() -> void:
	_freeIdle(_sfxPool)
	_freeIdle(_posPool)


# ============================================================
# 内部：资源查找与播放器池
# ============================================================

## 名字 -> AudioStream。查不到也缓存（存 null），这样写错名字不会反复查文件系统。
func _getSfx(sound: String) -> AudioStream:
	if sound.is_empty():
		return null
	if _sfxCache.has(sound):
		return _sfxCache[sound]
	var path: String = SFX_DIR + sound + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	elif OS.is_debug_build():
		push_warning("[SoundManage] 找不到音效 %s（%s）" % [sound, path])
	_sfxCache[sound] = stream
	return stream


## 名字 -> BGM AudioStream。查不到也缓存（存 null）。
func _getBgm(sound: String) -> AudioStream:
	if sound.is_empty():
		return null
	if _bgmCache.has(sound):
		return _bgmCache[sound]
	var path: String = BGM_DIR + sound + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	else:
		push_warning("[SoundManage] 找不到背景音乐 %s（%s）" % [sound, path])
	_bgmCache[sound] = stream
	return stream


func _acquire() -> AudioStreamPlayer:
	_reapDead(_sfxPool)
	# 先找空闲的
	for p in _sfxPool:
		if not p.playing:
			return p
	# 池子已经建满、又全在响 —— 抢最早开始的那个复用。
	# ⚠️ 不能"再 new 一个"，那样新建的没进池子，用完就永远漏着（这里踩过）
	if _sfxPool.size() >= sfxPoolSize:
		var oldest: AudioStreamPlayer = _sfxPool[0]
		for p in _sfxPool:
			if p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		return oldest
	var fresh: AudioStreamPlayer = AudioStreamPlayer.new()
	fresh.bus = "Sfx"
	add_child(fresh)
	_sfxPool.append(fresh)
	return fresh


func _acquire2d() -> AudioStreamPlayer2D:
	_reapDead(_posPool)
	for p in _posPool:
		if not p.playing:
			return p
	if _posPool.size() >= posPoolSize:
		var oldest: AudioStreamPlayer2D = _posPool[0]
		for p in _posPool:
			if p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		return oldest
	var fresh: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	fresh.bus = "Sfx"
	add_child(fresh)
	_posPool.append(fresh)
	return fresh


## 场景里有没有可用的听者。
##
## ⚠️ 不要再用 `get_nodes_in_group("cameras")` 找相机 —— Godot 4 的 Camera2D 只加入
##    `__cameras_<视口id>` / `__cameras_c<画布id>` 这种**带 id 的内部组**，
##    `"cameras"` 永远是空的。旧代码就是这么写的，结果听者检测一直返回 false，
##    所有 playAt() 都静默退化成了普通播放（没有声像、没有距离衰减）。
##
## 现在只认两种：
##   ① 场景里挂了 AudioListener2D 且是 current（map 的相机就是这种，见 custom_camera.tscn）；
##   ② 有启用的 Camera2D —— Godot 4 没有生效的 AudioListener2D 时，听者取**屏幕中心**
##      （不是节点原点），跟着相机动，所以有声像可用。
func _hasListener() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("audio_listener"):
		if n is AudioListener2D and (n as AudioListener2D).is_current():
			return true
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	var cam: Camera2D = vp.get_camera_2d()
	return cam != null and cam.enabled


func _freeIdle(pool: Array) -> void:
	for p in pool.duplicate():
		if is_instance_valid(p) and not p.playing:
			pool.erase(p)
			p.queue_free()


func _reapDead(pool: Array) -> void:
	for p in pool.duplicate():
		if not is_instance_valid(p):
			pool.erase(p)
