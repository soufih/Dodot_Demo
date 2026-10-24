class_name AbilityContext
extends RefCounted


var actor: CharacterBody2D
#var input: InputController
#var ani: AnimationPlayer
var state: StateManager


func _init(
	p_actor: CharacterBody2D,
	#p_input: InputController,
	#p_ani: AnimationPlayer,
	p_state: StateManager
) -> void:
	actor = p_actor
	#input = p_input
	#ani = p_ani
	state = p_state

func get_actor()->CharacterBody2D: return actor
#func get_input()->InputController: return input
#func get_ani()->AnimationPlayer: return ani
func get_state()->StateManager: return state
