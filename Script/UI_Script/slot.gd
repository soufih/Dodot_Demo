extends Button

var temporary_item_position:Vector2i = Vector2i(0,0)
var temporary_item_amount:Vector2i = Vector2i(0,0)
var temporary_item_texture:Texture2D = get_button_icon()
var button_down_sign = false

func _process(delta: float) -> void:
	if button_down_sign:
		button_down_sign = false
		temporary_item_texture.global_position = get_global_mouse_position()


func _on_button_down() -> void:
	print(get_mouse_position())
	button_down_sign = true

func _on_button_up() -> void:
	pass # Replace with function body.


func get_item():
	#获取鼠标点击格子位置
	var target_position:Vector2i = get_mouse_position()
	#获取信息
	var target_amount:Vector2i = BackpackSystem.get_item(target_position)
	var target_texture:Texture2D = get_button_icon()
	#存储信息
	restore_item(target_position,target_amount,target_texture)
	print(temporary_item_position)


func get_mouse_position()->Vector2i:
	var serial_number = get_parent().get_index()
	var column = get_parent().get_parent().get_columns()
	var x = serial_number / column + 1
	var y = serial_number % column + 1
	return Vector2i(x,y)


func restore_item(target_postion:Vector2i,target_amount:Vector2i,target_texture:Texture2D):
	temporary_item_position = target_postion
	temporary_item_amount = target_amount
	temporary_item_texture = target_texture
