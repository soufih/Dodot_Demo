extends BaseCharacter
class_name HeroProperty

signal god_mode
signal is_static
signal on_floor
signal is_fall
signal is_jump
signal end_jump
signal on_attack
signal end_attack

@onready var ani: AnimationPlayer = $PlayerAnimations
@onready var Spirte: AnimatedSprite2D = $heroSpirte
@onready var WeaponPivot:Node2D = $WeaponController/WeaponPivot

@export var CurrentWeapon:int
@export var GodModeTimer: float


func _ready() -> void:
	super.beginning()
	add_to_group("Hero")
	god_mode.connect(_on_god_mode)
	move_and_slide()


func _physics_process(delta: float) -> void:
	super.physics_running(delta)
	if velocity == Vector2(0,0):
		is_static.emit()
	
	if is_on_floor() && CurrentHealth > 0:
		on_floor.emit()
	else:
		is_fall.emit()


func filp_character()->void:
	if Input.get_action_strength("MoveRight"):
		WeaponPivot.scale.x = 1
		Spirte.flip_h = false
	elif Input.get_action_strength("MoveLeft"):
		WeaponPivot.scale.x = -1
		Spirte.flip_h = true


func _on_god_mode() -> void:
	set_collision_layer_value(2,false)
	set_collision_layer_value(7,true)
	$Godmode.start(GodModeTimer)
	await $Godmode.timeout
	set_collision_layer_value(2,true)
	set_collision_layer_value(7,false)
