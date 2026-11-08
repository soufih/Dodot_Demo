extends BaseUI
## 保留 K 键入口；窗口只绑定既有仓库。
@export var default_warehouse_id: String = "warehouse_home"
@onready var compound_ui = %Compound
@onready var warehouse_label: Label = %WarehouseLabel

func _ready() -> void:
	begin()
	%Exit.pressed.connect(request_close)

func on_open(payload: Dictionary) -> bool:
	if payload.has("warehouse_id") and not payload.warehouse_id is String:
		return false
	var id: String = payload.get("warehouse_id", default_warehouse_id)
	warehouse_label.text = "材料来源与产物去向：%s" % id
	compound_ui.bind(CraftingManager, id)
	return true

func on_close(_reason: StringName) -> void:
	compound_ui.unbind()
