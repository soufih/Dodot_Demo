extends Resource
class_name RoomConfig

#房间属性
@export var RoomType: ENUM.Type
@export var Entrance:ENUM.Location
@export var Exit:Array[bool] #左，上，右，下顺时针记录出口位置

#房间资源
@export var RoomPath:String
