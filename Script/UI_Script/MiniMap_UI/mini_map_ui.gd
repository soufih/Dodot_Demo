extends Control
## HUD 只接收已探索房间，不绘制或使用未探索房间来缩放地图。

const ROOM_COLOR := Color("354a58")
const ROOM_BORDER := Color("8299a5")
const CURRENT_COLOR := Color("786338")
const CURRENT_BORDER := Color("f5d58a")

@export var exploration: Node

@onready var map_canvas: Control = $Margin/Layout/MapCanvas

var _explored_rooms: Array[Dictionary] = []
var _current_room_id: int = -1


func _ready() -> void:
	map_canvas.draw.connect(_draw_map)
	map_canvas.resized.connect(map_canvas.queue_redraw)
	if exploration != null:
		exploration.exploration_changed.connect(_on_exploration_changed)
		_on_exploration_changed()


func _on_exploration_changed() -> void:
	_explored_rooms = exploration.get_explored_rooms()
	_current_room_id = exploration.current_room_id
	map_canvas.queue_redraw()


func _draw_map() -> void:
	if _explored_rooms.is_empty() or map_canvas.size.x <= 16.0 or map_canvas.size.y <= 16.0:
		return
	var bounds: Rect2 = _explored_rooms[0].bounds
	for room in _explored_rooms:
		bounds = bounds.merge(room.bounds)
	var available := map_canvas.size - Vector2(16, 16)
	var map_scale := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var origin := (map_canvas.size - bounds.size * map_scale) * 0.5
	var current_rect := Rect2()
	for room in _explored_rooms:
		var room_bounds: Rect2 = room.bounds
		var rect := Rect2(origin + (room_bounds.position - bounds.position) * map_scale, room_bounds.size * map_scale)
		var is_current: bool = room.id == _current_room_id
		map_canvas.draw_rect(rect, CURRENT_COLOR if is_current else ROOM_COLOR)
		map_canvas.draw_rect(rect, CURRENT_BORDER if is_current else ROOM_BORDER, false, 1.0)
		if is_current:
			current_rect = rect
	# 最后绘制当前房间，避免接缝覆盖高亮或标记。
	if current_rect.has_area():
		map_canvas.draw_rect(current_rect, CURRENT_BORDER, false, 2.0)
		map_canvas.draw_circle(current_rect.get_center(), 4.0, CURRENT_BORDER)
