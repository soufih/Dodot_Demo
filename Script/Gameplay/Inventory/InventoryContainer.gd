class_name InventoryContainer
extends RefCounted
## 仅保存数据；业务规则与受控修改由独占它的 Service 负责。

var container_id: String
var size: Vector2i
var cells: Array = []
var items: Dictionary = {}
var revision: int = 0

## 创建标识为 id、宽高为 dimensions 的空矩阵，每行独立且各格初始为 null。
## 内部构造函数；调用方负责预先校验 ID 与尺寸。
func _init(id: String, dimensions: Vector2i) -> void:
	container_id = id
	size = dimensions
	for y in range(size.y):
		var row: Array = []
		row.resize(size.x)
		cells.append(row)

## 返回 pos 位置的实例 ID 或 null；内部读取接口，坐标须已通过边界校验。
func get_cell(pos: Vector2i) -> Variant:
	return cells[pos.y][pos.x]

## 返回 id 对应的内部 {instance, anchor} 记录，不存在时返回空字典。
## 仅供服务内部访问；对外查询应复制记录，避免泄漏可变状态。
func get_item(id: int) -> Dictionary:
	return items.get(id, {})

## 返回包含身份、尺寸、矩阵、实例记录和版本的完整隔离快照，用于查询或事务暂存。
func snapshot() -> Dictionary:
	return copy_state({
		"container_id": container_id, "size": size, "cells": cells,
		"items": items, "revision": revision,
	})

## 深复制 state 的矩阵行及每条记录中的 ItemInstance，保留锚点和版本。
## Dictionary.duplicate(true) 不会复制 RefCounted，因此实例需逐个复制。
static func copy_state(state: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for id in state.items:
		var record: Dictionary = state.items[id]
		records[id] = {"instance": record.instance.copy(), "anchor": record.anchor}
	return {
		"container_id": state.container_id, "size": state.size,
		"cells": state.cells.duplicate(true), "items": records,
		"revision": state.revision,
	}
