extends BaseStateManager

@onready var Hitbox:Area2D = $"../AnimatedSprite2D/Hitbox"
@onready var SelfBody:BaseCharacter = $".."
@onready var ani:AnimationPlayer = $"../AnimationPlayer"

var Dead:bool = false
var Moving:bool = false
var Breaked:bool = false
var Attacking:bool = false

func check():
	if !Dead:
		if SelfBody.CurrentHealth <= 0:
			change_state(4)
			return

		if SelfBody.Toughness <= 0:
			change_state(3)
			return

		if Hitbox.has_overlapping_bodies() && !Attacking:
			for body in Hitbox.get_overlapping_bodies():
				if body.is_in_group("Hero"):
					change_state(2)
					return

		if !Moving && !Attacking:
			change_state(1)
			return
