extends Node

@onready var Hero: CharacterBody2D = $".."
@onready var Current: BaseState = $Idle
var StateArray: Array = []
var jumping:bool
var attacking:bool

func _ready() -> void:
	StateArray = get_children()
	Current.enter()

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	check()
	Current.do()
	
func change_state(id: int):
	Current.exit()
	Current = StateArray[id]
	Current.enter()

func check():
	if !jumping && !attacking:
		if Input.is_action_just_pressed("Attack") && Hero.is_on_floor():
			change_state(4)
		elif Input.is_action_just_pressed("Jump") && Hero.is_on_floor():
			change_state(2)
		elif (Input.is_action_just_pressed("MoveRight") || Input.is_action_just_pressed("MoveLeft")) && Hero.is_on_floor():
			change_state(1)
		elif Hero.velocity.x==0 && Hero.is_on_floor():
			change_state(0)
		elif !Hero.is_on_floor():
			change_state(3)

func _on_animated_sprite_2d_animation_finished() -> void:
	if $"../AnimatedSprite2D".animation == "Jump":
		change_state(1)
		jumping = false
	if $"../AnimatedSprite2D".animation == "Attack":
		attacking = false
