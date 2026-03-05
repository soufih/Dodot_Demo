extends BaseState

@export var JumpSpeed: int
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var holdTime:float
var maxHoldtime:float = 0.4

func enter():
	holdTime = 0
	get_parent().jumping = true
	Entity.velocity.y += -250
	AniPlayer.play("Jump")
	
	

func do(delta: float):
	if Input.is_action_pressed("Jump"):
		holdTime += delta
		if holdTime < maxHoldtime:
			Entity.velocity.y += -17

	Entity.filp_character()
	if Entity.velocity.y < 0:
		Entity.velocity.y = Entity.velocity.y + gravity*delta
	else:
		Entity.velocity.y = 0
		get_parent().jumping = false
	
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Entity.velocity.x = direct_x*Entity.Speed
	
	Entity.move_and_slide()

func exit():
	Entity.velocity = Vector2(0, 0)
	get_parent().jumping = false
