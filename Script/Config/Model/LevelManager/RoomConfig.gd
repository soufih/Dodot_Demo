extends Resource
class_name RoomConfig

#房间属性
@export var Name:String
@export var RoomType: ENUM.Type
@export var Entrance:ENUM.Location
@export var Exit:Array[ENUM.Location]

#房间资源
@export var RoomPath:PackedScene
