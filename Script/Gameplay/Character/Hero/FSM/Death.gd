extends BaseState

var _entry_id: int = 0
var _input_token := 0


func _on_enter():
	_entry_id += 1
	var entry_id := _entry_id
	Entity.velocity = Vector2.ZERO
	_input_token = UIManager.acquire_request(self, false, true, true)
	UIManager.ui_close_all()
	# 死亡仅关闭界面；会话装备与背包一起保留，由新游戏明确重置。
	AniPlayer.play("Death")
	AniPlayer.advance(0.0)
	# 方法轨道只启动精灵动画，等待精灵的实际死亡动画结束。
	if Entity.Spirte.is_playing():
		await Entity.Spirte.animation_finished
	if entry_id != _entry_id:
		return
	Entity.collision_layer = 0
	Entity.collision_mask = 0
	# 保留遗体和镜头，由场景切换统一释放。
	SignalBus.player_death.emit()
	_restore_ui_input()


func _on_exit():
	_entry_id += 1
	_restore_ui_input()


func _exit_tree() -> void:
	_restore_ui_input()


func _restore_ui_input() -> void:
	UIManager.release_request(_input_token)
	_input_token = 0
