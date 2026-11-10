class_name InventoryDefinition
extends Resource
## 容器静态定义，保存尺寸、槽位和初始物品配置，不持有运行期实例。

const InitialItem = preload("res://Script/Config/Model/ResourceManager/InventoryInitialItem.gd")

@export var container_id: String
## 界面显示名称；留空时使用窗口默认标题或容器 ID。
@export var display_name: String = ""
@export var size: Vector2i = Vector2i(8, 6)
@export var service_type: InventoryManager.ServiceType = InventoryManager.ServiceType.GRID
## 装备栏的静态槽位定义；普通和网格容器保持空数组。
@export var equipment_slots: Array[EquipmentSlotDefinition] = []
## 只在首次创建或显式新游戏时发放；重复绑定已存在的会话不补发。
@export var initial_items: Array[InitialItem] = []
