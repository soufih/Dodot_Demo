extends Button


var self_position:int
var self_icon:Texture2D
var self_id:int
const self_amount:int = 1
var tmp_slot


func _ready() -> void:
	init()
	EquipmentSlotSystem.equipment_slot_changed.connect(init)
	tmp_slot = DataLoader.tmp_slot


func init():
	self_position = get_self_position()

	if get_parent().get_parent().name == "WeaponSlot":
		self_id = 	EquipmentSlotSystem.get_equipment(self_position, EquipmentSlotSystem.get_weapon_slot())

	else:
		self_id = 	EquipmentSlotSystem.get_equipment(self_position, EquipmentSlotSystem.get_relic_slot())


	self_icon = ResourceManager.get_item_icon(self_id)
	set_button_icon(self_icon)


func get_self_position()->int:
	var serial_number = get_parent().get_index()
	var x = serial_number + 1
	return x


func _on_button_down() -> void:
	var result
	if get_parent().get_parent().name == "WeaponSlot":
		result = EquipmentSlotSystem.interact_with_equipment_slot(tmp_slot.get_tmp_item().x,tmp_slot.get_tmp_item().y,self_position, EquipmentSlotSystem.get_weapon_slot())
	else:
		result = EquipmentSlotSystem.interact_with_equipment_slot(tmp_slot.get_tmp_item().x, tmp_slot.get_tmp_item().y,self_position, EquipmentSlotSystem.get_relic_slot())


	tmp_slot.set_icon(result.x)
	tmp_slot.set_tmp_item(result.x, result.y)
	tmp_slot.set_button_down_sign(true)
