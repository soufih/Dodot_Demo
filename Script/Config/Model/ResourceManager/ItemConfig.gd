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
@export var Products: Array[int]
@export var Recipe: Dictionary[int, int]
@export var MainItemType:ENUM.ItemType = ENUM.ItemType.None
@export var ItemType:Array[ENUM.ItemType]
