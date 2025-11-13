extends Resource
class_name ItemConfig

#物品基础配置
@export var ItemID: int
@export var ItemName: String = ''
@export var ItemDiscription: String = ''
@export var ItemType:Array[ENUM.ItemType]

#资源路径
@export var IconTexture: Texture2D
@export var ScenePath: String = ''

#物品属性
@export var MaxStack: int = 1
@export var Source:Array[int]
@export var SourceDiscription: String = ''
