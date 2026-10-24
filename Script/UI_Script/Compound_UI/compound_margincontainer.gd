extends MarginContainer

@onready var root:BaseUI = $"../../../.."
@onready var item_list_ui:itemList = $HBoxContainer/compound_ui/item_list_ui
@onready var item_selector_ui:itemSelector = $HBoxContainer/compound_ui/item_selector_ui
@onready var item_name_label: Label = $HBoxContainer/detailed_information/MarginContainer/name
@onready var item_disciption_label: Label = $HBoxContainer/detailed_information/MarginContainer2/discription
@onready var item_recipe_list: itemList = $HBoxContainer/detailed_information/MarginContainer3/HBoxContainer/RecipeContainer/item_list_ui

##合成UI属性
var selector_condotion:Array
var current_selected_item:Dictionary= {
	"id": -1,
	"amount": 0
}
const maxItemcounts:int = 300

func _ready() -> void:
	item_list_ui.modify_items_list(select_displayed_items())
	if item_recipe_list:
		item_recipe_list.hide_when_empty(true)

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
			current_selected_item = {
				"id": -1,
				"amount": 0
			}
			return

##处理物品槽信号
func _on_item_list_ui_list_slot_pressed(item:Dictionary) -> void:
	item_name_label.text = item.itemName
	item_disciption_label.text = ResourceManager.get_item_discription(item.id)

	var recipe:Dictionary = ResourceManager.get_item_recipe(item.id)
	var result:Array = []
	for id in recipe:
		result.append({
			"id": id,
			"amount": recipe[id],
		})

	current_selected_item = item
	item_recipe_list.modify_items_list(result)

##处理筛选信号
func _on_item_selector_ui_selector_button_pressed(type: ENUM.ItemType) -> void:
	item_list_ui.modify_items_list(select_displayed_items())
