extends BaseState

@onready var FSM = $".."
@onready var Spirte = $"../../AnimatedSprite2D"

func enter():
	FSM.Attacking = true


func do(delta):
	FSM.ani.play("Attack")
	await Spirte.animation_finished



func apply_damage():
	for body in FSM.Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero") && Spirte.frame == 9:
			DamageSystem.damage_assess(FSM.SelfBody, body, FSM.SelfBody.Porperty)


func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero"):
		await Spirte.animation_finished
		FSM.Attacking = false
