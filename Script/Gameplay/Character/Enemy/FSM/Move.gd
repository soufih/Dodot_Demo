extends BaseState

@export var BarrierDetectLeft: Area2D
@export var BarrierDetectRight: Area2D
@export var Speed:int
@export var Hatebox:Area2D
@export var ChaseTarget := false

func _on_enter():
	AniPlayer.play("Move")
	
func _on_do(delta: float):
	var enemy := Entity as BaseEnemy
	var direction := enemy.facing_dir
	if ChaseTarget:
		for body in Hatebox.get_overlapping_bodies():
			if body.is_in_group("Hero"):
				var offset: float = body.global_position.x - enemy.global_position.x
				direction = int(signf(offset)) if absf(offset) > 1.0 else 0
				break

	# 两侧探测器保持固定，转向不会使本帧重叠结果变成另一侧的数据。
	if direction != 0 and _has_barrier(direction):
		if ChaseTarget:
			direction = 0
		else:
			direction = -direction
			if _has_barrier(direction):
				direction = 0

	enemy.set_move_direction(direction, Speed)
	Entity.velocity.y += DataLoader.gravity * delta
	Entity.move_and_slide()


func _has_barrier(direction: int) -> bool:
	var detector := BarrierDetectRight if direction > 0 else BarrierDetectLeft
	return detector.has_overlapping_bodies() or detector.has_overlapping_areas()
