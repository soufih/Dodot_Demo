extends TileMapLayer

@export var Level:String
var LevelPorperty:Array


func _ready() -> void:
	traverse_map(Vector2i(-1,0), Vector2i(0, 0), "LEFT", 0)
	save_level_template()
	var File = FileAccess.open("res://Rescource/LevelTemplate/"+Level+$".".name, FileAccess.READ)
	print(JSON.parse_string(File.get_line())[0])

func save_level_template():
	var File = FileAccess.open("res://Rescource/LevelTemplate/"+Level+$".".name, FileAccess.WRITE)

	File.store_line(JSON.stringify(LevelPorperty))

func traverse_map(Last: Vector2i, Now: Vector2i,Direct: String, Index:int):
	if get_cell_tile_data(Now) == null:
		return

	var RoomPorperty:Array=[]
	
	#添加房间类型
	RoomPorperty.append(get_cell_tile_data(Now).get_custom_data("RoomType"))
	#添加房间入口位置
	RoomPorperty.append(Direct)
	
	#计算添加房间出口位置
	RoomPorperty.append(Vector2i(Now.x+1,Now.y)	!= Last and get_cell_tile_data(Vector2i(Now.x+1,Now.y)) != null)
	RoomPorperty.append(Vector2i(Now.x,Now.y+1) != Last and get_cell_tile_data(Vector2i(Now.x,Now.y+1)) != null)
	RoomPorperty.append(Vector2i(Now.x-1,Now.y) != Last and get_cell_tile_data(Vector2i(Now.x-1,Now.y)) != null)
	RoomPorperty.append(Vector2i(Now.x,Now.y-1) != Last and get_cell_tile_data(Vector2i(Now.x,Now.y-1)) != null)
	
	#添加房间序号
	RoomPorperty.append(Index)
	
	LevelPorperty.append(RoomPorperty)

	#递归访问周围Tile
	if Vector2i(Now.x+1,Now.y) != Last:
		traverse_map(Now,Vector2i(Now.x+1,Now.y), "LEFT", Index+1)	
	if Vector2i(Now.x,Now.y+1) != Last:
		traverse_map(Now,Vector2i(Now.x,Now.y+1), "TOP", Index+1)
	if Vector2i(Now.x-1,Now.y) != Last:	
		traverse_map(Now,Vector2i(Now.x-1,Now.y), "RIGHT", Index+1)
	if Vector2i(Now.x,Now.y-1) != Last:	
		traverse_map(Now,Vector2i(Now.x,Now.y-1), "BOTTOM", Index+1)	
