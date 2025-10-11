extends BaseState

@onready var ani:AnimationPlayer = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D = $"../.."

func enter():
	ani.play("Idle")
	Hero.velocity = Vector2(0, Hero.velocity.y) 
	
func do(delta):
	pass
