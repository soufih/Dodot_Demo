extends HBoxContainer
## 仅绑定一个仓库；关闭解绑，不保存可执行计划。
const ITEM_VIEW: PackedScene = preload("res://UI/Crafting/crafting_item.tscn")
@onready var recipes: ItemList = %Recipes
@onready var category: OptionButton = %Category
@onready var available_only: CheckBox = %AvailableOnly
@onready var products: HFlowContainer = %Products
@onready var materials: HFlowContainer = %Materials
@onready var times: SpinBox = %Times
@onready var limit: Label = %Limit
@onready var status: Label = %Status
@onready var confirm: Button = %Confirm
var crafting_manager: Node
var warehouse_id: String = ""
var selected_recipe: StringName = &""

func _ready() -> void:
	category.add_item("全部配方", ENUM.ItemType.None)
	category.add_item("武器", ENUM.ItemType.Weapon)
	category.add_item("材料", ENUM.ItemType.Materials)
	category.add_item("遗物", ENUM.ItemType.Relic)
	category.add_item("装备", ENUM.ItemType.Equipment)
	recipes.item_selected.connect(_on_recipe_selected)
	category.item_selected.connect(func(_index: int): refresh())
	available_only.toggled.connect(func(_enabled: bool): refresh())
	times.value_changed.connect(func(_value: float): _refresh_details())
	confirm.pressed.connect(_craft)

func bind(manager: Node, id: String) -> void:
	unbind()
	crafting_manager = manager
	warehouse_id = id
	crafting_manager.inventory_manager.container_changed.connect(_on_container_changed)
	refresh()

func unbind() -> void:
	if is_instance_valid(crafting_manager):
		var source: Node = crafting_manager.inventory_manager
		if source.container_changed.is_connected(_on_container_changed):
			source.container_changed.disconnect(_on_container_changed)
	crafting_manager = null
	warehouse_id = ""
	selected_recipe = &""

func _exit_tree() -> void:
	unbind()

func refresh() -> void:
	if not is_instance_valid(crafting_manager):
		return
	recipes.clear()
	var selected_index := -1
	for recipe: CraftingRecipe in crafting_manager.list_recipes(category.get_selected_id()):
		if available_only.button_pressed:
			var check: InventoryResult = crafting_manager.preview(warehouse_id, recipe.recipe_id)
			if not check.is_ok() or check.payload.material_limit == 0:
				continue
		var first_id: int = recipe.outputs.keys()[0]
		var item_name := ResourceManager.get_item_name(first_id)
		var index := recipes.add_item("%s ×%d" % [item_name, recipe.outputs[first_id]], ResourceManager.get_item_icon(first_id))
		recipes.set_item_metadata(index, recipe.recipe_id)
		recipes.set_item_tooltip_enabled(index, false)
		if recipe.recipe_id == selected_recipe:
			selected_index = index
	if selected_index < 0 and recipes.item_count > 0:
		selected_index = 0
	selected_recipe = recipes.get_item_metadata(selected_index) if selected_index >= 0 else &""
	if selected_index >= 0:
		recipes.select(selected_index)
	_refresh_details()

func _on_recipe_selected(index: int) -> void:
	selected_recipe = recipes.get_item_metadata(index)
	_refresh_details()

func _refresh_details() -> void:
	if not is_instance_valid(crafting_manager):
		return
	confirm.disabled = true
	_clear_items(products)
	_clear_items(materials)
	if selected_recipe.is_empty():
		limit.text = ""
		status.text = "可调整分类或取消材料筛选。"
		return
	var result: InventoryResult = crafting_manager.preview(warehouse_id, selected_recipe, int(times.value))
	if not result.is_ok():
		limit.text = ""
		status.text = result.message
		return
	var data: Dictionary = result.payload
	for id: int in data.outputs:
		_add_item(products, id, "×%d" % data.outputs[id], Color("bde1ba"))
	for material: Dictionary in data.materials:
		var color := Color("f18d86") if material.missing > 0 else Color("bde1ba")
		var item := _add_item(materials, material.config_id, "%d / %d" % [material.owned, material.required], color)
		var has_recipe := not _find_material_recipe(material.config_id).is_empty()
		item.configure_material_tooltip(material, has_recipe)
		if has_recipe:
			item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			item.gui_input.connect(_on_material_input.bind(item, material.config_id))
	limit.text = "材料最多支持 %d 次；空间以当前预览为准" % data.material_limit
	confirm.disabled = not data.can_craft
	status.text = "材料与空间满足，产物将存入当前仓库。" if data.can_craft else data.reason

func _craft() -> void:
	if not is_instance_valid(crafting_manager) or selected_recipe.is_empty():
		return
	confirm.disabled = true
	var result: InventoryResult = crafting_manager.craft(warehouse_id, selected_recipe, int(times.value))
	refresh()
	status.text = "合成成功：已完成 %d 次，产物已存入仓库。" % result.payload.times if result.is_ok() else result.message

func _on_container_changed(id: String, _revision: int, _ids: Array[int]) -> void:
	if id == warehouse_id:
		refresh()

func _clear_items(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _add_item(container: Container, id: int, quantity: String, color: Color) -> PanelContainer:
	var item: PanelContainer = ITEM_VIEW.instantiate()
	item.get_node("Margin/Row/Icon").texture = ResourceManager.get_item_icon(id)
	item.get_node("Margin/Row/Quantity").text = quantity
	item.get_node("Margin/Row/Quantity").modulate = color
	container.add_child(item)
	return item

## 选择目录中第一份产出该材料的配方；不以材料是否足够限制配方浏览。
func _find_material_recipe(config_id: int) -> StringName:
	if is_instance_valid(crafting_manager):
		for recipe: CraftingRecipe in crafting_manager.list_recipes():
			if recipe.outputs.has(config_id):
				return recipe.recipe_id
	return &""

func _on_material_input(event: InputEvent, item: Control, config_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		item.accept_event()
		# 等当前输入分发结束，再替换承载本次点击的材料节点。
		_show_material_recipe.call_deferred(config_id)

func _show_material_recipe(config_id: int) -> void:
	var target := _find_material_recipe(config_id)
	if target.is_empty():
		return
	var listed := false
	for index in range(recipes.item_count):
		if recipes.get_item_metadata(index) == target:
			listed = true
			break
	# 被筛选隐藏的目标也能原地查看，并同步左侧总览的选择。
	if not listed:
		category.select(0)
		available_only.set_pressed_no_signal(false)
	selected_recipe = target
	times.set_value_no_signal(1)
	refresh()
	recipes.ensure_current_is_visible()
	(materials.get_parent() as ScrollContainer).scroll_vertical = 0
