extends Node
## 统计只属于本次生成的关卡，暂停不计时，结算或死亡后停止采集。

@export var generator: LevelGenerator

var _active := false
var _elapsed_seconds := 0.0
var _enemies_defeated := 0
var _bosses_defeated := 0
var _damage_dealt := 0.0
var _damage_taken := 0.0
var _items_collected: Dictionary[int, int] = {}
var _defeated_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if generator == null:
		return
	generator.level_generated.connect(_on_level_generated)
	generator.level_clearing.connect(_clear_statistics)
	SignalBus.character_damaged.connect(_on_character_damaged)
	SignalBus.enemy_defeated.connect(_on_enemy_defeated)
	SignalBus.item_picked_up.connect(_on_item_picked_up)
	SignalBus.level_completed.connect(_finish_statistics)
	SignalBus.player_death.connect(_finish_statistics)
	SignalBus.level_statistics_requested.connect(_publish_statistics)
	# 生成器在兄弟节点 ready 之前已完成首次生成。
	if generator.generation_succeeded:
		_on_level_generated()


func _process(delta: float) -> void:
	if _active:
		_elapsed_seconds += delta


func _on_level_generated() -> void:
	_clear_statistics()
	_active = true


func _clear_statistics() -> void:
	_active = false
	_elapsed_seconds = 0.0
	_enemies_defeated = 0
	_bosses_defeated = 0
	_damage_dealt = 0.0
	_damage_taken = 0.0
	_items_collected.clear()
	_defeated_ids.clear()


func _finish_statistics() -> void:
	_active = false


func _belongs_to_level(node: Node) -> bool:
	return is_instance_valid(node) and generator.is_ancestor_of(node)


func _is_player(node: Node) -> bool:
	return _belongs_to_level(node) and node.is_in_group("Hero")


func _on_character_damaged(source: BaseCharacter, target: BaseCharacter, amount: float) -> void:
	if not _active or not is_finite(amount) or amount <= 0.0:
		return
	if _is_player(source) and target is BaseEnemy and _belongs_to_level(target):
		_damage_dealt += amount
	if _is_player(target):
		_damage_taken += amount


func _on_enemy_defeated(enemy: BaseEnemy) -> void:
	if not _active or not _belongs_to_level(enemy) or _defeated_ids.has(enemy.get_instance_id()):
		return
	_defeated_ids[enemy.get_instance_id()] = true
	_enemies_defeated += 1
	if enemy.Porperty != null and enemy.Porperty.EnemyLevel == ENUM.EnemyLevel.Boss:
		_bosses_defeated += 1


func _on_item_picked_up(actor: Node, config_id: int, quantity: int) -> void:
	if _active and _is_player(actor) and quantity > 0:
		_items_collected[config_id] = _items_collected.get(config_id, 0) + quantity


## 返回独立快照，界面不能改写关卡统计。
func get_statistics() -> Dictionary:
	return {
		"elapsed_seconds": _elapsed_seconds,
		"enemies_defeated": _enemies_defeated,
		"bosses_defeated": _bosses_defeated,
		"damage_dealt": _damage_dealt,
		"damage_taken": _damage_taken,
		"items_collected": _items_collected.duplicate(),
	}


func _publish_statistics() -> void:
	if generator.generation_succeeded:
		SignalBus.level_statistics_updated.emit(get_statistics())
