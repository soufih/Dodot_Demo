class_name InventoryInitialItem
extends Resource
## 容器初始物品数据，不保存运行期实例；留空槽位标识时由快速添加自动选择位置。

@export var config_id: int
@export var quantity: int = 1
@export var rotated: bool = false
## 装备使用稳定槽位标识，例如 main_hand；普通背包留空。
@export var slot_id: StringName
