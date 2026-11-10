extends Resource
class_name ItemConfig

#物品基础配置
@export_category("BaseConfigtion")
@export var ItemID: int
@export var ItemName: String = ''
@export var ItemDiscription: String = ''


#资源路径
@export_category("ResourcePath")
@export var IconTexture: Texture2D
@export var ScenePath: String = ''

#物品属性
@export_category("Porperty")
@export var MaxStack: int = 1
@export var MainItemType:ENUM.ItemType = ENUM.ItemType.None
@export var ItemType:Array[ENUM.ItemType]

## 背包占位配置。未填写时使用单格、可旋转的默认规则。
@export_category("Inventory")
@export var GridSize: Vector2i = Vector2i.ONE
@export var CanRotate: bool = true

## 未设置时为普通物品；装备服务另行要求 MaxStack 为 1，不影响普通背包规则。
@export_category("Equipment")
@export var Equipment: EquipmentItemConfig

## 返回 MaxStack 与 GridSize 两轴是否均为正数；只读检查，不修改共享配置。
func validate() -> bool:
	return MaxStack > 0 and GridSize.x > 0 and GridSize.y > 0
