extends Control
## 在动态背景上绘制房间占地并集之外的填充区域。
## 范围来自生成完成后的 BaseLayer，包含内部空地及自动插入的走廊。

const FILL_COLOR = Color("#0f070d")

var room_bounds: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func outside_rectangles(view_rect: Rect2, openings: Array[Rect2]) -> Array[Rect2]:
	var remaining: Array[Rect2] = [view_rect]
	for opening in openings:
		var next: Array[Rect2] = []
		for area in remaining:
			var overlap := area.intersection(opening)
			if not overlap.has_area():
				next.append(area)
				continue
			# 将相交区域挖空，四个剩余矩形互不重叠。
			for piece in [
				Rect2(area.position, Vector2(overlap.position.x - area.position.x, area.size.y)),
				Rect2(Vector2(overlap.end.x, area.position.y), Vector2(area.end.x - overlap.end.x, area.size.y)),
				Rect2(Vector2(overlap.position.x, area.position.y), Vector2(overlap.size.x, overlap.position.y - area.position.y)),
				Rect2(Vector2(overlap.position.x, overlap.end.y), Vector2(overlap.size.x, area.end.y - overlap.end.y)),
			]:
				if piece.has_area():
					next.append(piece)
		remaining = next
	return remaining

func _draw() -> void:
	var canvas := get_viewport().get_canvas_transform()
	var openings: Array[Rect2] = []
	for bounds in room_bounds:
		openings.append(canvas * bounds)
	for area in outside_rectangles(Rect2(Vector2.ZERO, size), openings):
		draw_rect(area, FILL_COLOR)
