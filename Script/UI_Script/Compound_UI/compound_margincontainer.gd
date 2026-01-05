extends MarginContainer

@onready var root:BaseUI = $"../../../.."
@onready var item_list_ui:itemList = $HBoxContainer/compound_ui/item_list_ui
@onready var item_selector_ui:itemSelector = $HBoxContainer/compound_ui/item_selector_ui
@onready var item_name_label: Label = $HBoxContainer/detailed_information/MarginContainer/name
@onready var item_disciption_label: Label = $HBoxContainer/detailed_information/MarginContainer2/disciption
@onready var item_recipe_list: itemList = $HBoxContainer/detailed_information/MarginContainer3/HBoxContainer/item_list_ui

##合成UI属性
var selector_condotion:Array
const maxItemcounts:int = 5

func _ready() -> void:
	item_list_ui.modify_items_list(select_displayed_items())

func select_displayed_items()->Array:
	var items:Array[Dictionary]=[]

	##遍历物品列表
	for id in range(maxItemcounts):	
		if selector(id):
			items.append({
				"id": id,
				"amount": 1
				})

	var displayed_items = item_selector_ui.selector(items)
	return displayed_items

##筛选器
func selector(id: int)->bool:
	if ResourceManager.get_item_recipe(id).is_empty():	
		return false
	return true

##可见性改变时改变信号链接
func _on_visibility_changed() -> void:
	if root:
		if !root.visible || !visible:
			print("disconnect signal now")
			EventBus.slot_pressed.disconnect(_on_slot_pressed)
			EventBus.selector_button_pressed.disconnect(_on_selector_button_pressed)
			return

	if visible:
		print("connect signal now")
		EventBus.slot_pressed.connect(_on_slot_pressed)
		EventBus.selector_button_pressed.connect(_on_selector_button_pressed)


func _exit_tree() -> void:
	print("disconnect signal now")
	EventBus.slot_pressed.disconnect(_on_slot_pressed)
	EventBus.selector_button_pressed.disconnect(_on_selector_button_pressed)

##处理物品槽信号
func _on_slot_pressed(item:Dictionary):
	item_name_label.text = item.itemName
	item_disciption_label.text = ResourceManager.get_item_discription(item.id)

	var recipe:Dictionary = ResourceManager.get_item_recipe(item.id)
	var result:Array = []
	for id in recipe:
		result.append({
			"id": id,
			"amount": recipe[id],
		})
	item_recipe_list.modify_items_list(result)

##处理筛选信号
func _on_selector_button_pressed(type: ENUM.ItemType):
	item_list_ui.modify_items_list(select_displayed_items())
