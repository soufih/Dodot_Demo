extends BaseState

var _entry_id: int = 0
var _previous_input_ban := false
var _previous_ui_ban := false
var _ui_input_locked := false


func _on_enter():
	_entry_id += 1
	var entry_id := _entry_id
	Entity.velocity = Vector2.ZERO
	_previous_input_ban = Entity._InputController.is_banned
	Entity._InputController.ban_input(true)
	_previous_ui_ban = UIManager.is_banned
	_ui_input_locked = true
	UIManager.ban_ui_input()
	UIManager.ui_close_all()
	UIManager.is_paused = false
	BackpackSystem.clear_backpack()
	EquipmentSlotSystem.clear_equipment()
	UIManager.tmp_slot.clear_item()
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
	_restore_ui_input()
	SignalBus.player_death.emit()


func _on_exit():
	_entry_id += 1
	Entity._InputController.ban_input(_previous_input_ban)
	_restore_ui_input()


func _exit_tree() -> void:
	_restore_ui_input()


func _restore_ui_input() -> void:
	if _ui_input_locked:
		UIManager.is_banned = _previous_ui_ban
		_ui_input_locked = false
