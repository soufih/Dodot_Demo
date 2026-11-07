extends Control
## 仓库交互测试台；所有控件和窗口均由场景声明，脚本只绑定数据和翻译操作。

@export var item_catalog: ItemCatalog
@export var backpack_definition: InventoryDefinition
@export var warehouse_definition: InventoryDefinition
@export var populate_demo: bool = true
var initialization_result: InventoryResult
var _warehouse_open: bool = false
var _selected_container: String = ""
var _selected_instance_id: int = -1
@onready var manager = $Manager
@onready var forms = $Tools/Margin/Forms
@onready var details = $Details/Margin/Rows

## 建立独立会话并绑定已存在的两个窗口，失败时停止演示并显示真实错误。
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1700, 900)
	get_window().size = Vector2i(1700, 900)
	initialization_result = _initialize()
	if not initialization_result.is_ok():
		for node in forms.find_children("*", "BaseButton", true, false):
			node.disabled = true
		_on_operation_completed(initialization_result)
		return
	forms.get_node("Target").add_item("新增到背包", 0)
	forms.get_node("Target").add_item("新增到仓库", 1)
	for config in item_catalog.Item:
		forms.get_node("Item").add_item(config.ItemName, config.ItemID)
	_on_item_changed(0)
	manager.container_changed.connect(_on_container_changed)
	if populate_demo:
		_on_reset_pressed()
	else:
		_refresh_selection()
		_refresh_summary()

## 初始化服务与场景绑定；视图不会自行创建第二份物品状态。
func _initialize() -> InventoryResult:
	var result: InventoryResult = manager.configure(lookup_config)
	if not result.is_ok():
		return result
	for definition in [backpack_definition, warehouse_definition]:
		result = manager.create_container(definition.container_id, definition.size, definition.service_type)
		if not result.is_ok():
			return result
	result = $Workspace/Bag.bind(manager, backpack_definition.container_id, backpack_definition.service_type, lookup_config, backpack_definition.display_name)
	if not result.is_ok():
		return result
	result = $Workspace/Warehouse.bind(manager, warehouse_definition.container_id, warehouse_definition.service_type, lookup_config, warehouse_definition.display_name)
	_warehouse_open = result.is_ok()
	return result

## 只读查询演示目录，正式 ResourceManager 与玩家容器不受测试台影响。
func lookup_config(id: int) -> ItemConfig:
	for config in item_catalog.Item:
		if config.ItemID == id:
			return config
	return null

## 物品类型变化时将数量限制同步到配置的真实堆叠上限。
func _on_item_changed(_index: int) -> void:
	var config := lookup_config(forms.get_node("Item").get_selected_id())
	forms.get_node("Quantity").max_value = config.MaxStack

## 添加按钮用于生成新实例；已有物品的存取使用单独的事务按钮。
func _on_add_pressed() -> void:
	if not initialization_result.is_ok():
		return
	var target: String = backpack_definition.container_id if forms.get_node("Target").get_selected_id() == 0 else warehouse_definition.container_id
	if target == warehouse_definition.container_id and not _warehouse_open:
		return
	_on_operation_completed(manager.quick_add_to_container(target, forms.get_node("Item").get_selected_id(), int(forms.get_node("Quantity").value)))

## 存入所选背包物品，目标坐标来自用户表单。
func _on_deposit_pressed() -> void:
	_transfer(backpack_definition.container_id, warehouse_definition.container_id)

## 取回所选仓库物品，保留原实例身份和方向。
func _on_withdraw_pressed() -> void:
	_transfer(warehouse_definition.container_id, backpack_definition.container_id)

## 每次操作重新按实例 ID 解析锚点，避免整理之后使用旧选择位置。
func _transfer(source: String, target: String) -> void:
	if not _warehouse_open or _selected_container != source:
		return
	var record: Dictionary = manager.get_snapshot(source).items.get(_selected_instance_id, {})
	if record.is_empty():
		return
	var destination := Vector2i(int(forms.get_node("Destination/X").value), int(forms.get_node("Destination/Y").value))
	var result: InventoryResult = manager.switch_to_container(source, target, record.anchor, destination)
	if result.is_ok():
		_selected_container = target
		_selected_instance_id = record.instance.instance_id
	_refresh_selection()
	_on_operation_completed(result)

## 关闭只解绑并隐藏仓库视图，再次打开绑定原容器，不注销或重置物品。
func _on_toggle_pressed() -> void:
	if not initialization_result.is_ok():
		return
	if _warehouse_open:
		if get_viewport().gui_is_dragging():
			get_viewport().gui_cancel_drag()
		$Workspace/Warehouse.unbind()
		$Workspace/Warehouse.hide()
		_warehouse_open = false
		if _selected_container == warehouse_definition.container_id:
			_selected_container = ""
			_selected_instance_id = -1
	else:
		var result: InventoryResult = $Workspace/Warehouse.bind(manager, warehouse_definition.container_id, warehouse_definition.service_type, lookup_config, warehouse_definition.display_name)
		if not result.is_ok():
			_on_operation_completed(result)
			return
		$Workspace/Warehouse.show()
		_warehouse_open = true
	forms.get_node("Toggle").text = "隐藏仓库" if _warehouse_open else "打开仓库"
	_refresh_selection()
	$Status.text = "仓库已打开，物品保持原状。" if _warehouse_open else "仓库已隐藏，数据仍保留。"

## 显式重置演示物品，散放的仓库物品用于验证整理效果，不修改场景布局。
func _on_reset_pressed() -> void:
	if not initialization_result.is_ok():
		return
	_selected_container = ""
	_selected_instance_id = -1
	for definition in [backpack_definition, warehouse_definition]:
		for record: Dictionary in manager.get_snapshot(definition.container_id).items.values():
			manager.remove_from_container(definition.container_id, record.anchor)
	var seeds := [[1001, 1, Vector2i(0, 0)], [1002, 8, Vector2i(2, 0)], [1003, 1, Vector2i(3, 1)], [1004, 3, Vector2i(1, 3)]]
	var stored := [[1001, 1, Vector2i(1, 4)], [1002, 12, Vector2i(0, 8)], [1003, 1, Vector2i(3, 5)], [1004, 5, Vector2i(2, 2)]]
	for group in [[backpack_definition.container_id, seeds], [warehouse_definition.container_id, stored]]:
		for data in group[1]:
			var result: InventoryResult = manager.add_to_container(group[0], data[0], data[1], data[2])
			if not result.is_ok():
				_on_operation_completed(result)
				return
	_refresh_selection()
	_refresh_summary()
	$Status.text = "就绪 · 拖动物品存取，或选择物品后填写目标坐标；仓库标题中的「整理」可重新排列物品。"

## 仅保存选择身份，坐标和物品详情总是从最新快照读取。
func _on_item_selected(id: String, record: Dictionary) -> void:
	_selected_container = id if not record.is_empty() else ""
	_selected_instance_id = record.instance.instance_id if not record.is_empty() else -1
	_refresh_selection()

## 刷新已有控件中的详情与可用操作，不创建节点。
func _refresh_selection() -> void:
	var record: Dictionary = {}
	if not _selected_container.is_empty():
		record = manager.get_snapshot(_selected_container).items.get(_selected_instance_id, {})
	if record.is_empty():
		_selected_container = ""
		_selected_instance_id = -1
		details.get_node("Icon").texture = null
		details.get_node("Name").text = "选择一个物品"
		details.get_node("Data").text = "点击背包或仓库中的物品，查看数量、占格与实例信息。"
		details.get_node("Description").text = ""
		forms.get_node("Selection").text = "未选择物品"
	else:
		var config := lookup_config(record.instance.config_id)
		var source_name := "背包" if _selected_container == backpack_definition.container_id else "仓库"
		details.get_node("Icon").texture = config.IconTexture
		details.get_node("Name").text = config.ItemName
		details.get_node("Data").text = "来源：%s\n数量：%d\n占格：%s\n锚点：%s\n实例：%d" % [source_name, record.instance.quantity, record.instance.get_effective_size(config), record.anchor, record.instance.instance_id]
		details.get_node("Description").text = config.ItemDiscription
		forms.get_node("Selection").text = "%s · %s × %d" % [source_name, config.ItemName, record.instance.quantity]
	var source_is_bag := _selected_container == backpack_definition.container_id
	forms.get_node("Deposit").disabled = not (_warehouse_open and source_is_bag)
	forms.get_node("Withdraw").disabled = not (_warehouse_open and _selected_container == warehouse_definition.container_id)
	var destination_size: Vector2i = warehouse_definition.size if source_is_bag else backpack_definition.size
	forms.get_node("Destination/X").max_value = destination_size.x - 1
	forms.get_node("Destination/Y").max_value = destination_size.y - 1
	forms.get_node("Add").disabled = not _warehouse_open and forms.get_node("Target").get_selected_id() == 1

## 新增物品目标改变时同步按钮状态，隐藏仓库期间仍可向背包添加。
func _on_target_changed(_index: int) -> void:
	_refresh_selection()

## 提交后更新选择与统计；失败命令没有数据变化通知。
func _on_container_changed(_id: String, _revision: int, _ids: Array[int]) -> void:
	_refresh_selection()
	_refresh_summary()

## 摘要直接反映当前两个容器容量与物品数。
func _refresh_summary() -> void:
	var bag: Dictionary = manager.get_snapshot(backpack_definition.container_id)
	var warehouse: Dictionary = manager.get_snapshot(warehouse_definition.container_id)
	$Summary.text = "背包 %d 件 · %d × %d    /    仓库 %d 件 · %d × %d" % [bag.items.size(), bag.size.x, bag.size.y, warehouse.items.size(), warehouse.size.x, warehouse.size.y]

## 成功与失败都显示服务实际结果，失败不会预扣物品。
func _on_operation_completed(result: InventoryResult) -> void:
	$Status.text = "操作成功" if result.is_ok() else "操作失败：" + result.message
