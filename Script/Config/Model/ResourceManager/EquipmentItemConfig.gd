class_name EquipmentItemConfig
extends Resource
## 物品的装备适配规则；不包含角色属性、场景节点或 UI 引用。

## 在检查器中通过枚举选择类型；NONE 表示尚未配置，不能穿戴。
@export var equipment_type: ENUM.EquipmentType = ENUM.EquipmentType.NONE
## 装备此物品时必须为空的槽位标识，例如双手武器要求副手槽为空。
## 未出现在当前布局中的标识忽略，使同一物品配置可用于不同装备栏布局。
@export var blocked_slot_ids: Array[StringName] = []

## 类型必须是已定义且非 NONE 的枚举值，声明的阻塞槽位标识必须非空。
func validate() -> bool:
	return equipment_type != ENUM.EquipmentType.NONE and ENUM.EquipmentType.values().has(equipment_type) \
		and blocked_slot_ids.all(func(id: StringName) -> bool: return not String(id).strip_edges().is_empty())
