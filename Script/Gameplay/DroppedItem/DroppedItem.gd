extends RigidBody2D
class_name DroppedItem

@onready var Spirte:Sprite2D = $DropGlow

@export var min_force: float = 400
@export var max_force: float = 500

var Launched:bool = false
## 世界中的待拾取清单；每条只保存配置 ID 与数量，不提前创建背包实例。
@export var items: Array[Dictionary] = []
var _collecting: bool = false

## 生成时接收清单副本，人物掉落配置与世界剩余量互不影响。
func configure(item_list: Array) -> void:
	items.clear()
	for entry in item_list:
		items.append({"id": int(entry.id), "amount": int(entry.amount)})
	_update_visual()

## 将各条清单交给接收者，只有实际成功入包的数量才从地面扣除。
## 接收者返回 InventoryResult，成功 payload 为已接收数量；可部分成功并保留余量。
func collect(receiver: Callable) -> InventoryResult:
	if _collecting or items.is_empty() or is_queued_for_deletion():
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "掉落物正在处理或已拾取")
	_collecting = true
	var accepted := 0
	var ids: Array[int] = []
	var last_error: InventoryResult
	var remaining: Array[Dictionary] = []
	for entry in items:
		var result: InventoryResult = receiver.call(entry.id, entry.amount)
		if result.is_ok():
			entry.amount -= result.payload
			accepted += result.payload
			ids.append_array(result.affected_ids)
		else:
			last_error = result
		if entry.amount > 0:
			remaining.append(entry)
	items = remaining
	_update_visual()
	_collecting = false
	if items.is_empty():
		queue_free()
	if accepted > 0:
		var result := InventoryResult.success(accepted, ids, true)
		result.message = "已拾取 %d 件" % accepted
		if not items.is_empty():
			result.message += "，剩余物品未入包，请腾出空间后重试"
		return result
	return last_error

## 首条显示名称与剩余数量，多条清单额外提示类型数。
func get_pickup_text() -> String:
	if items.is_empty():
		return "已拾取"
	var item_name := ResourceManager.get_item_name(items[0].id)
	if item_name.is_empty():
		item_name = "物品 %d" % items[0].id
	return "拾取 %s × %d%s" % [item_name, items[0].amount,
		" 等 %d 种" % items.size() if items.size() > 1 else ""]

## 图标和数量节点来自掉落场景，配置先于 ready 时延后到初始化中刷新。
func _update_visual() -> void:
	if not is_node_ready() or items.is_empty():
		return
	$ItemIcon.texture = ResourceManager.get_item_icon(items[0].id)
	if $ItemIcon.texture != null:
		var dimensions: Vector2 = $ItemIcon.texture.get_size()
		$ItemIcon.scale = Vector2.ONE * 24.0 / maxf(dimensions.x, dimensions.y)
	$Amount.text = "%d 种" % items.size() if items.size() > 1 else str(items[0].amount)

#将掉落物弹射出去
func _ready() -> void:
	_update_visual()
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
