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
signal on_climb
signal end_climb
## 实际进入/退出攀爬状态的通知，区别于状态切换请求。
signal climb_started
signal climb_finished
## 组件通过请求信号修改剩余次数，通过变化信号监听结果。
signal jump_count_change_requested(amount: int)
signal jump_count_reset_requested
signal jump_count_changed(remaining: int, maximum: int)
signal skill_control_requested(event: StringName)
signal jump_limit_requested(source: StringName, maximum: int)
signal jump_limit_removed(source: StringName)

signal end_dash_ground
signal end_dash_air

var _jump_limits: Dictionary[StringName, int] = {}
var _base_jump_limit := 0
var _was_on_floor := false
## 固定能力列表；每个人物独立维护启用情况，避免多个实例共享解锁。
var enabled_abilities: Dictionary[StringName, bool] = {&"dash": false}

func is_ability_enabled(id: StringName) -> bool:
	return enabled_abilities.get(id, false)

func set_ability_enabled(id: StringName, enabled: bool) -> void:
	if enabled_abilities.has(id):
		enabled_abilities[id] = enabled

func _enter_tree() -> void:
	if not jump_limit_requested.is_connected(_on_jump_limit_requested):
		jump_limit_requested.connect(_on_jump_limit_requested)
		jump_limit_removed.connect(_on_jump_limit_removed)

func _on_jump_limit_requested(source: StringName, maximum: int) -> void:
	if _base_jump_limit == 0:
		_base_jump_limit = MaxJumpCount
	_jump_limits[source] = maxi(maximum, 1)
	_update_jump_limit()

func _on_jump_limit_removed(source: StringName) -> void:
	if _jump_limits.erase(source):
		_update_jump_limit()

func _update_jump_limit() -> void:
	var previous_max := MaxJumpCount
	var previous_remaining := CurrentJumpCount
	var maximum := _base_jump_limit
	for value in _jump_limits.values():
		maximum = maxi(maximum, value)
	MaxJumpCount = maximum
	_set_jump_count(previous_remaining + maximum - previous_max)

@onready var ani: AnimationPlayer = $PlayerAnimations
@onready var Spirte: AnimatedSprite2D = $HeroSpirte
@onready var WeaponPivot:Node2D = $WeaponController/WeaponPivot
@onready var _InputController:InputController = $InputController

@export var GodModeTimer: float
@export var mainCamera: Camera2D
@export var InteractBox:Area2D
@export var GodmodeTimer: Timer

@export_category("Jump")
@export_range(1, 10, 1, "or_greater") var MaxJumpCount: int = 1:
	set(value):
		var previous_maximum := MaxJumpCount
		MaxJumpCount = maxi(value, 1)
		var previous_count := CurrentJumpCount
		_set_jump_count(mini(CurrentJumpCount, MaxJumpCount))
		if previous_maximum != MaxJumpCount and previous_count == CurrentJumpCount:
			jump_count_changed.emit(CurrentJumpCount, MaxJumpCount)
var CurrentJumpCount: int = 1
@export_range(0.1, 3.0, 0.1) var JumpSpeedMultiplier: float = 1.0 #跳跃加速度

@export_category("Fall")
@export var safe_fall_speed = 800  # 安全下落速度
@export var max_fall_speed = 1500  # 最大下落速度
@export var base_damage = 10  # 基础伤害

func _ready() -> void:
	process_physics_priority = 90
	jump_count_change_requested.connect(_on_jump_count_change_requested)
	jump_count_reset_requested.connect(_on_jump_count_reset_requested)
	climb_started.connect(_on_jump_count_reset_requested)
	_on_jump_count_reset_requested()
	_InputController.ban_input(true)
	super.beginning()
	add_to_group("Hero")
	god_mode.connect(_on_god_mode)
	move_and_slide()
	_was_on_floor = is_on_floor()


func _physics_process(delta: float) -> void:
	super.physics_running(delta)
	if velocity == Vector2(0,0):
		is_static.emit()
	
	if is_on_floor() && CurrentHealth > 0:
		# 起跳后的首次移动前，地面检测仍保留上一帧结果。
		if velocity.y >= 0.0:
			jump_count_reset_requested.emit()
		on_floor.emit()
	else:
		# 走出平台消耗地面起跳机会，起跳已扣次数时不重复扣除。
		if _was_on_floor and CurrentJumpCount == MaxJumpCount:
			_set_jump_count(CurrentJumpCount - 1)
		is_fall.emit()
	_was_on_floor = is_on_floor()


func get_jump_count() -> int:
	return CurrentJumpCount


func can_continue_jump() -> bool:
	return CurrentJumpCount > 0


func _set_jump_count(value: int) -> void:
	var remaining := clampi(value, 0, MaxJumpCount)
	if CurrentJumpCount == remaining:
		return
	CurrentJumpCount = remaining
	jump_count_changed.emit(CurrentJumpCount, MaxJumpCount)


func _on_jump_count_change_requested(amount: int) -> void:
	_set_jump_count(CurrentJumpCount + amount)


func _on_jump_count_reset_requested() -> void:
	_set_jump_count(MaxJumpCount)


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
