extends Button

## UI 按钮的点击音**统一在这里播**。
##
## ⚠️ 约定：用了这个预制体的按钮，场景脚本**不要再调一次** `SoundManage.playXxx()`，
##    否则一次点击会听到两声。想换声音请改下面的 `click_sound`，
##    而不是在场景脚本里另外补一句。
##
## 地图内想要更"重"的一声，把 `click_sound` 切成 CONFIRM 即可。
##
## 另外鼠标**移上来**会播一声轻的悬停音（`sfx/ui_hover.ogg`），
## 同样由这个脚本自己负责，场景脚本不要再补。

enum ClickSound {
	COIN,     ## 菜单 / 通用 UI（sfx/coin.ogg）
	CONFIRM,  ## 地图内按钮（sfx/ui_confirm.ogg）
}

## 同一个按钮在这个间隔内只认一次点击。
## 真人的连续点击远慢于它，但一次点击被重复派发（两条信号路径 / 重复事件）会落进窗口里被吃掉。
const CLICK_GUARD_MSEC := 120

@export var click_sound: ClickSound = ClickSound.COIN

var _last_click_msec: int = -100000


func _on_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_click_msec < CLICK_GUARD_MSEC:
		return
	_last_click_msec = now
	match click_sound:
		ClickSound.CONFIRM:
			SoundManage.playConfirm()
		_:
			SoundManage.playEffect()


## 鼠标移上来播一声轻的（sfx/ui_hover.ogg）。
## 节流在 SoundManage 里（HOVER_GUARD_MSEC），这里只负责触发。
func _on_mouse_entered() -> void:
	if disabled:
		return
	SoundManage.playHover()
