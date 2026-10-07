@tool
extends StaticBody2D
## 三角形实体斜坡，原点位于底边左端；尺寸及朝向可在 Inspector 调整。

@export var slope_size: Vector2 = Vector2(128, 64):
	set(value):
		slope_size = value.max(Vector2.ONE)
		_update_shape()
@export var rise_to_right: bool = true:
	set(value):
		rise_to_right = value
		_update_shape()
@export var show_surface: bool = true:
	set(value):
		show_surface = value
		_update_shape()
@export var surface_color: Color = Color(0.16, 0.19, 0.21, 1.0):
	set(value):
		surface_color = value
		_update_shape()

func _ready() -> void:
	_update_shape()

func _update_shape() -> void:
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	var surface := get_node_or_null("Surface") as Polygon2D
	if collision == null or surface == null:
		return
	var points: PackedVector2Array
	if rise_to_right:
		points = PackedVector2Array([Vector2.ZERO, Vector2(slope_size.x, -slope_size.y), Vector2(slope_size.x, 0)])
	else:
		points = PackedVector2Array([Vector2(0, -slope_size.y), Vector2(slope_size.x, 0), Vector2.ZERO])
	if Engine.is_editor_hint() or not is_inside_tree():
		collision.polygon = points
	else:
		collision.set_deferred("polygon", points)
	surface.polygon = points
	surface.color = surface_color
	surface.visible = show_surface
