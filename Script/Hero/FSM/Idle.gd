extends BaseState

@onready var ani:AnimationPlayer = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D = $"../.."

func enter():
	ani.play("Idle")

	
