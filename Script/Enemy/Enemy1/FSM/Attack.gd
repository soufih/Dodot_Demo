extends BaseState

@onready var FSM = $".."
@onready var Spirte = $"../../AnimatedSprite2D"

func enter():
	FSM.Attacking = true


func do(delta):
	FSM.ani.play("Attack")
	await Spirte.animation_finished
	
	for body in FSM.Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			var HeroPos = body.global_position
			var SelfPos = FSM.SelfBody.global_position
			if FSM.SelfBody.scale.y*(HeroPos.x-SelfPos.x) > 0:
				FSM.SelfBody.scale.x = abs(FSM.SelfBody.scale.x)
			else:
				FSM.SelfBody.scale.x = -abs(FSM.SelfBody.scale.x)
			
			if HeroPos > SelfPos:
				$"../Move".Direct = 1
			else:
				$"../Move".Direct = -1


func apply_damage():
	for body in FSM.Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero") && Spirte.frame == 9:
			print(Spirte.frame)
			DamageSystem.damage_assess(FSM.SelfBody, body, FSM.SelfBody.Porperty)


func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero"):
		await Spirte.animation_finished
		FSM.Attacking = false
