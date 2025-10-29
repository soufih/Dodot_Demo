extends Node

var InforLevelRoomLog:LevelRoomLog
var InforLevelTemplateLog:LevelTemplateLog

func _ready() -> void:
	load_level_room_log()
	load_level_template_log()

func load_level_room_log():
	InforLevelRoomLog = load("res://Rescource/LevelRoomLog.tres") as LevelRoomLog
	if !InforLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")
		
func load_level_template_log():
	InforLevelTemplateLog = load("res://Rescource/LevelTemplateLog.tres") as LevelTemplateLog
	if !InforLevelTemplateLog:
		push_error("ERRO!WHEN LOAD LEVEL TEMPLATE")
	
func get_level_rooms(Level:int)->LevelRoomConfig:
	if InforLevelRoomLog:
		return InforLevelRoomLog.LevelTemplate[Level]
	return null

func get_level_template(Level:int)->TemplateConfig:
	if InforLevelTemplateLog:
		return InforLevelTemplateLog.LevelLog[Level]
	return null
	
func random_select_level_template(Level:int)->Array:
	var CurrentLevelTemplates:Array = get_level_template(Level).TempaltePath
	var Size = CurrentLevelTemplates.size()
	
	var Result = FileAccess.open(CurrentLevelTemplates[randi()%Size], FileAccess.READ)
	if Result == null:
		push_error("ERRO!WHEN ACCESS TEMPLATE FILE", FileAccess.get_open_error())
	return JSON.parse_string(Result.get_line())
	
func select_room(Level:int):
	var Template = random_select_level_template(Level)
	var Room =  get_level_rooms(Level)

func assemble_room():
	pass
