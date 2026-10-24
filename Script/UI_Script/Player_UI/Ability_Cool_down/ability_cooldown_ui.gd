extends HBoxContainer

const Item = preload(Path.SKILL_COOLDOWN_ITEM_SCRIPT)

var entries: Dictionary[StringName, Node] = {}
var _player: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_owner() as Node2D
	SignalBus.ability_cooldown_start.connect(_on_started)


func _on_started(player: Node2D, id: StringName, ico: Texture2D, cooldown: float) -> void:
	if player != _player or cooldown <= 0.0:
		return

	var item: Item
	if entries.has(id) and is_instance_valid(entries[id]):
		item = entries[id] as Item
	else:
		item = Item.new()
		entries[id] = item
		add_child(item)

	item.start_cooldown(id, ico, cooldown)
	show()


func _exit_tree() -> void:
	if SignalBus.ability_cooldown_start.is_connected(_on_started):
		SignalBus.ability_cooldown_start.disconnect(_on_started)
