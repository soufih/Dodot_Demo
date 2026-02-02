extends BaseState

signal is_dead

func enter():
	is_dead.emit()
	AniPlayer.play("Death")
	await AniPlayer.animation_finished
	EnemyManager.drop(Entity.name, Entity.global_position)
	Entity.queue_free()
