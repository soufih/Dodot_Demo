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
@onready var Spirte: AnimatedSprite2D = $HeroSpirte
@onready var WeaponPivot:Node2D = $WeaponController/WeaponPivot
@onready var _InputController:InputController = $InputController

@export var GodModeTimer: float
@export var mainCamera: Camera2D
@export var InteractBox:Area2D
@export var GodmodeTimer: Timer

@export_category("Jump")
@export var JumpHeight: float = 20#基础跳跃高度
@export var MaxJumpHeight: float = 30#最大跳跃高度
@export_range(0.1, 3.0, 0.1) var JumpSpeedMultiplier: float = 1.0 #跳跃加速度

@export_category("Fall")
@export var safe_fall_speed = 800  # 安全下落速度
@export var max_fall_speed = 1500  # 最大下落速度
@export var base_damage = 10  # 基础伤害

func _ready() -> void:
	_InputController.ban_input(true)
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
	if _InputController.get_move_direction() == 1:
		WeaponPivot.scale.x = 1
		Spirte.flip_h = false
	elif _InputController.get_move_direction() == -1:
		WeaponPivot.scale.x = -1
		Spirte.flip_h = true


func _on_god_mode() -> void:
	set_collision_layer_value(2,false)
	set_collision_layer_value(7,true)
	GodmodeTimer.start(GodModeTimer)
	await GodmodeTimer.timeout
	set_collision_layer_value(2,true)
	set_collision_layer_value(7,false)


func _on_entry_timer_timeout() -> void:
	_InputController.ban_input(false)
