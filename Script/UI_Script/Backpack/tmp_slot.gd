extends Marker2D
class_name TmpSlot

@onready var Icon:Sprite2D = $Sprite2D
var TmpID: int = -1
var TmpAmount: int = 1
var button_down_sign = false

func _ready() -> void:
	#鼠标拖动物品图标显示于最上层
	z_index = 10

func _process(_delta: float) -> void:
	#临时物品图标跟随鼠标移动
	if button_down_sign:
		global_position = get_global_mouse_position()

##设置临时物品图标s
func set_icon(id:int):
	Icon.set_texture(ResourceManager.get_item_icon(id))

##设置临时物品数据
func set_tmp_item(id:int, amount:int):
	TmpID = id
	TmpAmount = amount

##获取临时物品数据
func get_tmp_item():
	return Vector2i(TmpID, TmpAmount)

func refresh():
	set_icon(TmpID)

func set_button_down_sign(state:bool):
	button_down_sign = state
