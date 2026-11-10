extends BaseState

@export var drop_component: DropComponent

signal is_dead

func _on_enter():
	(Entity as BaseEnemy).set_move_direction(0, 0.0)
	Entity.velocity = Vector2.ZERO
	SignalBus.enemy_defeated.emit(Entity as BaseEnemy)
	is_dead.emit()
	AniPlayer.play("Death")
	await AniPlayer.animation_finished
	drop_component.drop()
	Entity.queue_free()
