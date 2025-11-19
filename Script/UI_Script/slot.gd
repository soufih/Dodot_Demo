extends Button

#var temporary_item_position:Vector2i = Vector2i(0,0)
#var temporary_item_amount:Vector2i = Vector2i(0,0)
#var temporary_item_texture:Texture2D = get_button_icon()
@onready var label_item_amount: Label = $Label_item_amount

var button_down_sign = false
var self_position:Vector2i
var self_icon:Texture2D
var self_id:int
var self_amount:int
var self_index:int
var tmp_slot:TmpSlot

func _ready() -> void:
	init()
	BackpackSystem.backpack_changed.connect(init)


func _process(delta: float) -> void:
	#临时物品图标跟随鼠标移动
	if button_down_sign:
		tmp_slot.global_position = get_global_mouse_position()


func init():
	self_position = get_self_position()
	var item = BackpackSystem.get_item_by_postion(self_position)
	
	self_id = item.x
	self_amount = item.y
	self_icon = ResourceManager.get_item_icon(self_id)
	set_button_icon(ResourceManager.get_item_icon(self_id))
	#显示物品数量
	if self_amount > 1:
		label_item_amount.text = "%s" % self_amount
		label_item_amount.show()
	else:
		label_item_amount.hide()


func get_self_position()->Vector2i:
	var serial_number = get_parent().get_index()
	var column = get_parent().get_parent().get_columns()
	var x = serial_number / column + 1
	var y = serial_number % column + 1
	return Vector2i(x,y)


func _on_button_down() -> void:
	tmp_slot = get_parent().get_parent().get_parent().get_parent().get_parent().get_node("tmp_slot")
	var result:Vector2i = BackpackSystem.interact_with_slot(tmp_slot.get_tmp_item().x, tmp_slot.get_tmp_item().y, self_position)
	print(result)
	print(self_position)
	
	tmp_slot.set_icon(result.x)
	tmp_slot.set_tmp_item(result.x, result.y)
	button_down_sign = true


#func _on_button_up() -> void:
	#pass


#func get_item():
	##获取鼠标点击格子位置
	#var target_position:Vector2i = get_mouse_position()
	##获取信息
	#var target_amount:Vector2i = BackpackSystem.get_item(target_position)
	#var target_texture:Texture2D = get_button_icon()
	##存储信息
	#restore_item(target_position,target_amount,target_texture)
	##print(temporary_item_position)


#func restore_item(target_postion:Vector2i,target_amount:Vector2i,target_texture:Texture2D):
	##temporary_item_position = target_postion
	##temporary_item_amount = target_amount
	#temporary_item_texture = target_texture
