extends PanelContainer
class_name itemSelector


func _on_button_button_down() -> void:
	EventBus.emit_signal("selector_button_pressed")


func _on_button_2_button_down() -> void:
	EventBus.emit_signal("selector_button_pressed")


func _on_button_3_button_down() -> void:
	EventBus.emit_signal("selector_button_pressed")


func _on_button_4_button_down() -> void:
	EventBus.emit_signal("selector_button_pressed")


func _on_button_5_button_down() -> void:
	EventBus.emit_signal("selector_button_pressed")
