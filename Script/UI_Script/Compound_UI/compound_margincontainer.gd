extends MarginContainer

@onready var item_list_ui:itemList = $HBoxContainer/compound_ui/item_list_ui
@onready var item_selector_ui = $HBoxContainer/compound_ui/item_selector_ui
@onready var item_name_label: Label = $HBoxContainer/detailed_information/MarginContainer/name
@onready var item_disciption_label: Label = $HBoxContainer/detailed_information/MarginContainer2/disciption
@onready var item_recipe_list: itemList = $HBoxContainer/detailed_information/MarginContainer3/HBoxContainer/item_list_ui

##合成UI属性
var item_list:Array[int]
var selector_condotion:Array
const maxItemcounts:int = 5


func _ready() -> void:
	item_list_ui.modify_items_list(select_displayed_items())

func select_displayed_items()->Array:
	var displayed_items:Array=[]

	##遍历物品列表
	for id in range(maxItemcounts):
		if selector(id):
			displayed_items.append({
				"id": id,
				"amount": 1
				})
	
	return displayed_items

##筛选器
func selector(id: int)->bool:
	if ResourceManager.get_item_recipe(id).size() == 0:
		return false
	return true

##可见性改变时改变信号链接
func _on_visibility_changed() -> void:
	if visible:
		EventBus.slot_pressed.connect(_on_slot_pressed)
		EventBus.selector_button_pressed.connect(_on_selector_button_pressed)
	else:
		EventBus.slot_pressed.disconnect(_on_slot_pressed)
		EventBus.selector_button_pressed.disconnect(_on_selector_button_pressed)

##处理物品槽信号
func _on_slot_pressed(item:Dictionary):
	item_name_label.text = item.itemName
	item_disciption_label.text = ResourceManager.get_item_discription(item.id)

	var recipe = ResourceManager.get_item_recipe(item.id)
	var result:Array = []
	for id in recipe:
		result.append({
			"id": id,
			"amount": 1,
		})
	item_recipe_list.modify_items_list(result)

func _on_selector_button_pressed():
	pass
