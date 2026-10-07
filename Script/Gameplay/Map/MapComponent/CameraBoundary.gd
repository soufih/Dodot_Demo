@tool
extends Node2D
class_name CameraBoundary
## 摄像机允许显示的世界区域，不参与角色物理碰撞。
## 可从房间 BaseLayer 自动读取，也可手动设置矩形。

@export var enabled: bool = true:
	set(value):
		enabled = value
		_request_refresh()
@export var priority: int = 0:
	set(value):
		priority = value
		_request_refresh()
@export var fit_tile_map: bool = true:
	set(value):
		fit_tile_map = value
		_request_refresh()
@export_node_path("TileMapLayer") var tile_map_path: NodePath = NodePath("../BaseLayer"):
	set(value):
		tile_map_path = value
		_request_refresh()
@export var bounds: Rect2 = Rect2(-480, -270, 960, 540):
	set(value):
		bounds = value
		_request_refresh()

var _sensor: Area2D
var _shape: CollisionShape2D
var _players: Array[Node2D] = []
var _refresh_pending := false

func _ready() -> void:
	add_to_group("CameraBoundary")
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		_sensor = Area2D.new()
		_sensor.name = "PlayerDetector"
		_sensor.collision_layer = 0
		# 普通角色层及玩家无敌状态层，不改变角色的实体碰撞。
		_sensor.collision_mask = 2 | 64
		_sensor.monitorable = false
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		_sensor.add_child(_shape)
		add_child(_sensor)
		_sensor.body_entered.connect(_on_body_entered)
		_sensor.body_exited.connect(_on_body_exited)
		set_notify_transform(true)
		refresh_bounds()
		var tiles := get_node_or_null(tile_map_path) as TileMapLayer
		if tiles != null:
			tiles.changed.connect(_request_refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_request_refresh()


func _request_refresh() -> void:
	if not is_node_ready() or _refresh_pending:
		return
	_refresh_pending = true
	refresh_bounds.call_deferred()


func refresh_bounds() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	if is_instance_valid(_shape):
		var local_bounds := global_transform.affine_inverse() * get_world_bounds()
		_shape.position = local_bounds.get_center()
		_shape.shape.size = local_bounds.size.max(Vector2(0.001, 0.001))
	if not Engine.is_editor_hint():
		SignalBus.camera_boundary_changed.emit(self)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Hero") or _players.has(body):
		return
	_players.append(body)
	SignalBus.camera_room_entered.emit(body, self)


func _on_body_exited(body: Node2D) -> void:
	if not _players.has(body):
		return
	_players.erase(body)
	SignalBus.camera_room_exited.emit(body, self)


func _exit_tree() -> void:
	# @tool 脚本在编辑器热重载时，成员可能尚未完成初始化。
	if Engine.is_editor_hint() or _players == null:
		return
	var players := _players.duplicate()
	_players.clear()
	var signal_bus := get_node_or_null("/root/SignalBus")
	if not is_instance_valid(signal_bus):
		return
	for player in players:
		if is_instance_valid(player):
			signal_bus.camera_room_exited.emit(player, self)

func _process(_delta: float) -> void:
	queue_redraw()

func get_world_bounds() -> Rect2:
	if fit_tile_map:
		var tiles := get_node_or_null(tile_map_path) as TileMapLayer
		if tiles != null and tiles.tile_set != null:
			var cells := tiles.get_used_rect()
			var tile_size := Vector2(tiles.tile_set.tile_size)
			if cells.has_area():
				return tiles.global_transform * Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)
	return global_transform * bounds.abs()

func _draw() -> void:
	if Engine.is_editor_hint() and enabled:
		var rect := global_transform.affine_inverse() * get_world_bounds()
		draw_rect(rect, Color(0.2, 0.8, 1.0, 0.08))
		draw_rect(rect, Color(0.2, 0.8, 1.0, 0.9), false, 2.0)
