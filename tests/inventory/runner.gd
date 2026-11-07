extends Node
## 由 runner.tscn 承载节点，测试代码不硬编码生成场景节点。

## 依次运行各背包测试套件和现有资源兼容性检查，输出汇总并以成功/失败退出码结束。
func _ready() -> void:
	var checks = preload("res://tests/inventory/spec_context.gd").new()
	preload("res://tests/inventory/service_spec.gd").new().run(checks)
	preload("res://tests/inventory/manager_spec.gd").new().run(checks, $Manager, $OtherManager)
	preload("res://tests/inventory/stack_spec.gd").new().run(checks, $Manager)
	preload("res://tests/inventory/split_spec.gd").new().run(checks, $Manager)
	preload("res://tests/inventory/quick_add_spec.gd").new().run(checks, $Manager)
	preload("res://tests/inventory/drag_rotation_spec.gd").new().run(checks, $Manager)
	preload("res://tests/inventory/manager_boundary_spec.gd").new().run(checks, $Manager)
	preload("res://tests/inventory/invariant_spec.gd").new().run(checks)
	preload("res://tests/inventory/cross_invariant_spec.gd").new().run(checks, $Manager)
	_test_existing_catalog(checks)
	print("INVENTORY_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 通过真实 ItemCatalog、ResourceManager 与 InventoryManager 验证旧资源配置和默认接入。
func _test_existing_catalog(t) -> void:
	# 使用真正的 Autoload 和现有 .tres，验证新增配置字段兼容旧物品。
	var catalog: ItemCatalog = ResourceManager.ReferItemCatalog
	t.expect(catalog != null and not catalog.Item.is_empty(), "现有物品目录加载成功")
	if catalog == null or catalog.Item.is_empty():
		return
	for config in catalog.Item:
		t.expect(config.validate(), "现有配置有效：%s" % config.ItemID)
	t.code(InventoryManager.create_container("catalog_smoke", Vector2i.ONE, InventoryManager.ServiceType.GRID), InventoryResult.Code.OK, "真实 Autoload 创建容器")
	t.code(InventoryManager.add_to_container("catalog_smoke", catalog.Item[0].ItemID, 1, Vector2i.ZERO), InventoryResult.Code.OK, "真实 ResourceManager 配置查询")
	t.code(InventoryManager.unregister_container("catalog_smoke"), InventoryResult.Code.OK, "真实 Autoload 清理")
