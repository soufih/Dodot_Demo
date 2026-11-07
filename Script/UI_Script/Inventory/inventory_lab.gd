extends Control
## 可独立运行的测试台；表单、窗口和组件均由 .tscn 声明或实例化。

@export var item_catalog: ItemCatalog
@export var window_scene: PackedScene
@export var populate_demo: bool = true

@onready var manager = $Manager
@onready var workspace: Control = $Layout/Rows/Main/Workspace
@onready var container_form = $Layout/Rows/Main/Tools/Margin/Forms/ContainerForm
@onready var item_form = $Layout/Rows/Main/Tools/Margin/Forms/ItemForm
@onready var selection_form = $Layout/Rows/Main/Tools/Margin/Forms/Selection
@onready var status: Label = $Layout/Rows/Status/Margin/Message

var windows: Dictionary = {}
var _selected: Dictionary = {}

## 注入测试目录并绑定现有表单，默认展示两个容器和几件示例物品。
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	manager.configure(lookup_config)
	container_form.get_node("Type").add_item("网格背包", InventoryManager.ServiceType.GRID)
	container_form.get_node("Type").add_item("普通背包", InventoryManager.ServiceType.SLOT)
	for config in item_catalog.Item:
		item_form.get_node("Config").add_item("%s  ·  %d×%d" % [config.ItemName, config.GridSize.x, config.GridSize.y], config.ItemID)
	_on_config_selected(0)
	# 等待布局容器完成排序，窗口初始位置和边界限制才能使用真实工作区尺寸。
	await get_tree().process_frame
	if populate_demo:
		create_container("旅行背包", Vector2i(6, 4), InventoryManager.ServiceType.GRID)
		create_container("储物箱", Vector2i(4, 3), InventoryManager.ServiceType.SLOT)
		#manager.add_to_container("旅行背包", 1001, 1, Vector2i(0, 0))
		#manager.add_to_container("旅行背包", 1002, 8, Vector2i(2, 0))
		#manager.add_to_container("旅行背包", 1003, 1, Vector2i(3, 1))
		manager.quick_add_to_container("旅行背包", 1004, 3)
		manager.quick_add_to_container("储物箱", 1004, 3)
		_set_target("旅行背包")
	_show_message("就绪 · 拖动时按 R 旋转；同类堆叠，不同物品交换；中键取一半，右键或 Esc 取消。", true)

## 只读查询独立目录，演示配置不会写回共享的实际物品资源。
func lookup_config(id: int) -> ItemConfig:
	for config in item_catalog.Item:
		if config.ItemID == id:
			return config
	return null

## 先创建数据容器，再实例化完整窗口场景；返回 Manager 的统一结果。
func create_container(id: String, dimensions: Vector2i, service_type: int) -> InventoryResult:
	var result: InventoryResult = manager.create_container(id, dimensions, service_type)
	if not result.is_ok():
		_show_result(result)
		return result
	var view = window_scene.instantiate()
	workspace.add_child(view)
	view.bind(manager, id, service_type, lookup_config)
	view.item_selected.connect(_on_item_selected)
	view.operation_completed.connect(_show_result)
	view.focused.connect(_set_target)
	view.position = Vector2(24, 26) + Vector2(240, 156) * (windows.size() % 3)
	view.position = view.position.clamp(Vector2.ZERO, (workspace.size - view.size).max(Vector2.ZERO))
	windows[id] = view
	item_form.get_node("Target").add_item(id)
	_set_target(id)
	$Layout/Rows/Header/Count.text = "%02d 个容器" % windows.size()
	_show_message("已创建容器：%s" % id, true)
	return result

## 从添加容器表单读取 ID、类型和矩阵宽高，不在视图中推断占位规则。
func _on_create_container_pressed() -> void:
	var id: String = container_form.get_node("Name").text.strip_edges()
	var dimensions := Vector2i(int(container_form.get_node("Dimensions/Width").value), int(container_form.get_node("Dimensions/Height").value))
	create_container(id, dimensions, container_form.get_node("Type").get_selected_id())

## 从表单构造实例，由 Manager 快速添加至首个适配位置，位置由具体服务选择。
func _on_add_item_pressed() -> void:
	var target = item_form.get_node("Target")
	if target.selected < 0:
		_show_message("请先添加一个容器。", false)
		return
	_show_result(manager.quick_add_to_container(target.get_item_text(target.selected),
		item_form.get_node("Config").get_selected_id(), int(item_form.get_node("Amount").value),
		item_form.get_node("Rotated").button_pressed))

## 选择配置时显示旋转能力和堆叠范围，表单仍由 Manager 做最终校验。
func _on_config_selected(_index: int) -> void:
	var config := lookup_config(item_form.get_node("Config").get_selected_id())
	item_form.get_node("Amount").max_value = config.MaxStack
	item_form.get_node("Rotated").disabled = not config.CanRotate
	item_form.get_node("Rotated").button_pressed = false

## 聚焦窗口时同步添加物品的目标，不重新注册或清空容器。
func _set_target(id: String) -> void:
	var target = item_form.get_node("Target")
	for index in range(target.item_count):
		if target.get_item_text(index) == id:
			target.select(index)
			return

## 保存选择的快照记录，展示说明；所有后续命令仍通过 Manager 重新校验。
func _on_item_selected(id: String, record: Dictionary) -> void:
	_selected = {"container_id": id, "record": record} if not record.is_empty() else {}
	selection_form.get_node("Rotate").disabled = record.is_empty()
	selection_form.get_node("Remove").disabled = record.is_empty()
	selection_form.get_node("Description").text = "未选择物品"
	if not record.is_empty():
		var config := lookup_config(record.instance.config_id)
		selection_form.get_node("Description").text = "%s × %d\n%s · (%d, %d)" % [config.ItemName, record.instance.quantity, id, record.anchor.x, record.anchor.y]
		selection_form.get_node("Rotate").disabled = not config.CanRotate

## 在当前锚点旋转所选实例，失败时方向及占位保持原值。
func _on_rotate_pressed() -> void:
	if _selected.is_empty():
		return
	var id: String = _selected.container_id
	var record: Dictionary = _selected.record
	var result: InventoryResult = manager.rotate_in_container(id, record.anchor, not record.instance.rotated)
	_show_result(result)
	if result.is_ok():
		_on_item_selected(id, manager.get_item_at(id, record.anchor))

## 移除完整选中栈，成功后清理选择，避免把脱离实例误认为仍在容器中。
func _on_remove_pressed() -> void:
	if _selected.is_empty():
		return
	var result: InventoryResult = manager.remove_from_container(_selected.container_id, _selected.record.anchor)
	_show_result(result)
	if result.is_ok():
		_on_item_selected("", {})

## 显示统一结果；预览查询不会覆盖正式操作的状态消息。
func _show_result(result: InventoryResult) -> void:
	if result.is_ok() and result.payload is Vector2i:
		_show_message("已添加物品至 (%d, %d)" % [result.payload.x, result.payload.y], true)
		return
	if result.is_ok() and result.payload is int:
		_show_message("已堆叠 %d 件物品" % result.payload, true)
		return
	_show_message("操作成功" if result.is_ok() else "操作失败 · %s" % result.message, result.is_ok())

## 将反馈写入场景内已有 Label，成功与失败有不同颜色且始终附带文字。
func _show_message(message: String, success: bool) -> void:
	status.text = message
	status.modulate = Color("b9dec9") if success else Color("ffb4a6")
