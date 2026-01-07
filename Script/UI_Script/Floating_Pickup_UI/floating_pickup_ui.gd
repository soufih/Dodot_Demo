extends CanvasLayer

# 导出一个动画时长变量，方便在编辑器中调整
@export var animation_duration: float = 0.3

# 定义Tween节点，用于动画效果
var tween: Tween

# 节点引用
@onready var panel: PanelContainer = $PanelContainer
@onready var icon_texture: TextureRect = $PanelContainer/HBoxContainer/icon_texture
@onready var name_label: Label = $PanelContainer/HBoxContainer/name_label
@onready var count_label: Label = $PanelContainer/HBoxContainer/count_label


func _ready():
	# 初始时隐藏
	hide()
	# 创建Tween节点用于动画
	tween = create_tween()


# 公共方法：用于显示拾取提示
func show_pickup():
	 #1. 更新UI内容
	icon_texture.texture = null
	name_label.text = ''
	count_label.text = "x" + ''

	# 2. 重置动画和显示UI
	show()
	tween.kill() # 停止任何正在进行的动画
	panel.modulate.a = 0 # 完全透明
	panel.rect_position.y = -panel.rect_size.y # 从屏幕外上方开始

	# 3. 创建淡入和上移动画
	tween.set_parallel(true) # 让下面两个动画同时播放
	tween.tween_property(panel, "modulate:a", 1.0, animation_duration) # 淡入
	tween.tween_property(panel, "rect_position:y", 20.0, animation_duration) # 向上移动到目标位置
	tween.set_parallel(false)

	# 4. 等待几秒钟后，创建淡出和下移动画
	tween.tween_delay(2.0)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, animation_duration)
	tween.tween_property(panel, "rect_position:y", -panel.rect_size.y, animation_duration)
	tween.set_parallel(false)

	# 5. 动画结束后，隐藏整个CanvasLayer
	tween.tween_callback(self.hide)
