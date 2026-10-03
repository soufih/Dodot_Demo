extends BaseState

var _entry_id: int = 0
var _previous_input_ban := false


func enter():
	_entry_id += 1
	var entry_id := _entry_id
	Entity.velocity = Vector2.ZERO
	_previous_input_ban = Entity._InputController.is_banned
	Entity._InputController.ban_input(true)
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


func exit():
	_entry_id += 1
	Entity._InputController.ban_input(_previous_input_ban)
