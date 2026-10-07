extends BaseState

@export var drop_component: DropComponent

signal is_dead

func _on_enter():
	Entity.velocity = Vector2.ZERO
	is_dead.emit()
	AniPlayer.play("Death")
	await AniPlayer.animation_finished
	drop_component.drop()
	Entity.queue_free()
