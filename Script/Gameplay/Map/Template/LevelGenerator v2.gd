extends Node

static var ReferLevelRoomLog:LevelRoomLog
var RoomSpace:Dictionary[Marker2D ,Rect2i]

#加载房间列表
func load_level_room_log():
	if ReferLevelRoomLog:
		return
	ReferLevelRoomLog = load("uid://dh3a2qfk263s4") as LevelRoomLog
	if !ReferLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")

#加载房间
func get_level_rooms(level:int)->LevelRoomConfig:
	if ReferLevelRoomLog:
		var result = ReferLevelRoomLog.LevelLog.get(level)
		if result:
			return result
	return null

#将枚举量与字符串映射
var TYPE = ['Start', 'Corridor', 'Room', 'End']
var ENTRANCE = ['LEFT','RIGHT','TOP','BOTTOM']

#检查房间 确定是否合适
func check_room(Room:RoomConfig)->bool:
	return true

func generate_level(level: int):
	var roomConfiglog = get_level_rooms(level)
