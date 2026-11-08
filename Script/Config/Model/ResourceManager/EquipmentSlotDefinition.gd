class_name EquipmentSlotDefinition
extends Resource
## 装备槽静态规则；数组中的顺序对应服务内部 N × 1 矩阵的列索引。

@export var slot_id: StringName
## 与物品的 equipment_type 使用同一枚举，允许一个槽接收多种装备类型。
@export var accepted_types: Array[ENUM.EquipmentType] = []
## 数值越小越优先；相同优先级按槽位配置顺序选择，不自动替换已有装备。
@export var auto_equip_priority: int = 0

## 槽位必须有标识及至少一种有效枚举类型；标识唯一性由服务初始化时检查。
func validate() -> bool:
	return not String(slot_id).strip_edges().is_empty() and not accepted_types.is_empty() \
		and accepted_types.all(func(type: ENUM.EquipmentType) -> bool:
			return type != ENUM.EquipmentType.NONE and ENUM.EquipmentType.values().has(type))
