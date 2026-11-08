class_name InventoryDefinition
extends Resource
## 容器静态定义；只保存标识、尺寸和服务类型，不持有运行期物品。

@export var container_id: String
## 界面显示名称；留空时使用窗口默认标题或容器 ID。
@export var display_name: String = ""
@export var size: Vector2i = Vector2i(8, 6)
@export var service_type: InventoryManager.ServiceType = InventoryManager.ServiceType.GRID
## 装备栏的静态槽位定义；普通和网格容器保持空数组。
@export var equipment_slots: Array[EquipmentSlotDefinition] = []
