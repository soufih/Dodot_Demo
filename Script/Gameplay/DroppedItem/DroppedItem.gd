extends RigidBody2D
class_name DroppedItem

@onready var Spirte:Sprite2D = $DropGlow
@onready var PickupArea:Area2D = $PickupArea

@export var min_force: float = 400
@export var max_force: float = 500

var Items:Array
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

#向掉落物中添加物品
func add_item(item_list: Array):
	Items = item_list

#获取掉落物
func get_items()->Array:
	return Items

#拾取掉落物
func _on_pickup_area_body_entered(body: Node2D) -> void:
	# 死亡动画期间仍可能发生重叠，遗体不能再次拾取物品。
	if body is HeroProperty and body.CurrentHealth <= 0.0:
		return
	if body.is_in_group("Hero"):
		var remain:Vector2i
		var tmp_queue:Array
		#将物品加入背包
		for item in Items:
			remain = BackpackSystem.quick_add_item(item.id, item.amount)
			if remain.y == 0:
				tmp_queue.append(item)#加入待移除队列
			else:
				Items[item.id] = remain.y

		#移除标记物品
		for i in tmp_queue:
			Items.erase(i)
		
		if Items.is_empty():
			queue_free()
