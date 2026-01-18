extends BaseUI
class_name pickupMention

@export var animation_duration: float = 0.5

@onready var icon: TextureRect = $HBoxContainer/icon_texture
@onready var item_name: Label = $HBoxContainer/name_label
@onready var amount: Label = $HBoxContainer/amount_label
var tween: Tween

func _ready() -> void:
	# 创建Tween节点用于动画
	modulate.a = 0
	show_pickup()


# 公共方法：用于显示拾取提示
func show_pickup():
	tween = create_tween()
	#向右移动淡入
	tween.tween_property(self, "global_position:x", 0, animation_duration)
	tween.parallel().tween_property(self, "modulate:a", 1, animation_duration)

	tween.tween_interval(1)

	#向上移动淡出
	tween.tween_property(self, "global_position:y", 200, animation_duration)
	tween.parallel().tween_property(self, "modulate:a", 0, animation_duration)
	tween.tween_callback(queue_free)

func set_display(item: Dictionary):
	icon.texture = ResourceManager.get_item_icon(item.id)
	item_name.text = ResourceManager.get_item_name(item.id)
	amount.text = "x "+str(item.amount) 
