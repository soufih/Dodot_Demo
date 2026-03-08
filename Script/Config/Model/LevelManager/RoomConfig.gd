extends Resource
class_name RoomConfig

#房间属性
@export var Name:String
@export var RoomType: ENUM.Type
@export var Entrance:ENUM.Location
@export var Entrance_v2:ENUM.Location_v2
@export var Exit:Array[bool] #左，上，右，下顺时针记录出口位置
@export var Exit_v2:Array[ENUM.Location_v2]

#房间资源
@export var RoomPath:String
