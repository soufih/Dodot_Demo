extends BaseState
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D = $"../.."

func enter():
	ani.play("Falling")
	
	
func do(delta):
	Hero.velocity = lerp(Hero.velocity, Vector2(0, Hero.velocity.y), delta*10)
	
