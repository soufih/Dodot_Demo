extends Resource
class_name RoomConfig

#房间属性
enum Type {Start, Corridor, Other, End}
@export var RoomType: Type

enum Location {LEFT,RIGHT,TOP,BOTTOM}
@export var Entrance:Location
@export var Exit:Array[bool] #左，上，右，下顺时针记录出口位置

#房间资源
@export var RoomPath:String
