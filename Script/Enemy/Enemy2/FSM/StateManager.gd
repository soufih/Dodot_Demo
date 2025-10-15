extends BaseStateManager

@onready var Hitbox:Area2D = $"../Hitbox"
@onready var SelfBody:CharacterBody2D = $".."
@onready var ani:AnimationPlayer = $"../AnimationPlayer"

var Dead:bool = false
var Moving:bool = false
var Attacking:bool = false

func check():
	if !Dead:
		if SelfBody.get_character_current_health() == 0:
			change_state(4)
			return
			
		if Hitbox.has_overlapping_bodies() && !Attacking:
			for body in Hitbox.get_overlapping_bodies():
				if body.is_in_group("Hero"):
					body.position.normalized()
					change_state(2)
					return
		
		if !Moving && !Attacking:
			change_state(1)
			return
	
