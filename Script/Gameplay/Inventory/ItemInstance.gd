class_name ItemInstance
extends RefCounted
## 一个实例表示一个栈；不保存位置或容器，避免重复状态源。

static var _next_id: int = 1

var instance_id: int
var config_id: int
var quantity: int
var rotated: bool

## 创建配置为 config、数量为 amount、方向为 rotation 的物品栈。
## id=0 时分配运行期 ID；显式 ID 用于复制/接管，实例合法性由写入服务校验。
func _init(config: int = 0, amount: int = 1, rotation: bool = false, id: int = 0) -> void:
	instance_id = id if id != 0 else _next_id
	_next_id = maxi(_next_id, instance_id + 1)
	config_id = config
	quantity = amount
	rotated = rotation

## 返回数量是否小于等于零；仅查询状态，不自动从容器移除。
func is_empty() -> bool:
	return quantity <= 0

## 读取所属 config 的网格尺寸，rotated=true 时交换宽高。
## 仅计算尺寸，不检查 CanRotate；普通背包不使用此尺寸。
func get_effective_size(config: ItemConfig) -> Vector2i:
	return Vector2i(config.GridSize.y, config.GridSize.x) if rotated else config.GridSize

## 复制实例的 ID、配置、数量和方向；保留身份，但可变字段与原对象独立。
func copy() -> ItemInstance:
	return ItemInstance.new(config_id, quantity, rotated, instance_id)
