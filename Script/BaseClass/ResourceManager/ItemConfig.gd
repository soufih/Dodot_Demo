extends Resource
class_name ItemConfig

#物品基础配置
@export var ItemID: int
@export var ItemName: String = ''
@export var ItemDiscription: String = ''
@export var ItemType:String = ''

#资源路径
@export var IconTexture: Texture2D
@export var ScenePath: String = ''
@export var SoundPath: String = ''

#物品属性
@export var MaxStack: int = 1
