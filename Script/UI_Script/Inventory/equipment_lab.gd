extends Control
## 独立装备交互测试台；窗口、分组、槽位与表单均在场景中搭建。

@export var item_catalog: ItemCatalog
@export var equipment_definition: InventoryDefinition
@export var populate_demo: bool = true
@onready var manager = $Manager
const BAG_ID := "测试背包"
var _initialized: bool = false

## 初始化独立数据服务，绑定场景中的两个窗口，不改变 Autoload 或正式物品目录。
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	var result := _initialize_views()
	if not result.is_ok():
		$Workspace/Equipment.unbind()
		$Toolbar/Add.disabled = true
		$Toolbar/Reset.disabled = true
		_on_operation_completed(result)
		return
	for config in item_catalog.Item:
		$Toolbar/Item.add_item(config.ItemName, config.ItemID)
	_initialized = true
	if populate_demo:
		_on_reset_pressed()

## 依次检查创建和绑定结果；任何一步失败都保留真实错误，不进入演示填充流程。
func _initialize_views() -> InventoryResult:
	var result: InventoryResult = manager.configure(lookup_config)
	if not result.is_ok():
		return result
	result = manager.create_container(BAG_ID, Vector2i(5, 8), InventoryManager.ServiceType.GRID)
	if not result.is_ok():
		return result
	result = PlayerInventorySession.ensure(equipment_definition, manager)
	if not result.is_ok():
		return result
	result = $Workspace/Bag.bind(manager, BAG_ID, InventoryManager.ServiceType.GRID, lookup_config)
	if not result.is_ok():
		return result
	return $Workspace/Equipment.bind(manager, equipment_definition.container_id, InventoryManager.ServiceType.EQUIPMENT_SLOT, lookup_config, equipment_definition.display_name)

## 按配置 ID 查找演示物品，供服务与视图共同使用同一份只读配置。
func lookup_config(id: int) -> ItemConfig:
	for config in item_catalog.Item:
		if config.ItemID == id:
			return config
	return null

## 将所选物品添加到演示背包，空间和数量仍由服务检查。
func _on_add_pressed() -> void:
	if not _initialized:
		return
	var id: int = $Toolbar/Item.get_selected_id()
	_on_operation_completed(manager.quick_add_to_container(BAG_ID, id))

## 清空两个演示容器并重新提供测试物品；不重建 UI 节点或重新排列布局。
func _on_reset_pressed() -> void:
	if not _initialized:
		return
	for id in [BAG_ID, equipment_definition.container_id]:
		for record: Dictionary in manager.get_snapshot(id).items.values():
			manager.remove_from_container(id, record.anchor)
	for config in item_catalog.Item:
		manager.quick_add_to_container(BAG_ID, config.ItemID)
	$Status.text = "就绪 · 把长剑拖到主武器，短剑拖到副武器；普通物品不可穿戴。"

## 显示真实命令结果，不将拖放预览当作已成功穿戴。
func _on_operation_completed(result: InventoryResult) -> void:
	$Status.text = "操作成功" if result.is_ok() else "操作失败：" + result.message

## 展示选择信息，便于确认同类槽位中的实例身份彼此独立。
func _on_item_selected(id: String, record: Dictionary) -> void:
	$Selection.text = "未选择物品" if record.is_empty() else "%s · %s · 实例 %d" % [id, lookup_config(record.instance.config_id).ItemName, record.instance.instance_id]
