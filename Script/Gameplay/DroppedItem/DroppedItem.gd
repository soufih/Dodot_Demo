extends RigidBody2D
class_name DroppedItem

@onready var Spirte:Sprite2D = $DropGlow

@export var min_force: float = 400
@export var max_force: float = 500

var Launched:bool = false

#将掉落物弹射出去
func _ready() -> void:
	Spirte.set_instance_shader_parameter("phase_offset", randf_range(0.0, TAU))

	var angle_deg = randf_range(60, 120)
	var angle_rad = deg_to_rad(angle_deg)
	
	# 随机力度
	var force_magnitude = randf_range(min_force, max_force)
	
	# 计算力向量
	var force_vector = Vector2(cos(angle_rad)*force_magnitude,-sin(angle_rad)*force_magnitude)
	
	# 应用冲量
	apply_central_impulse(force_vector)

func _process(_delta: float) -> void:
	#冻结掉落物减少性能开销
	if linear_velocity.x < 1 && linear_velocity.y < 1 && Launched:
		freeze = true

func _on_freeze_timer_timeout() -> void:
	Launched = true
