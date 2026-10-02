extends Node

## 全局弹幕池：作为 Autoload 持有节点，统一管理弹幕的复用和回收。
## 发射时直接传入 .tres 资源；不同弹幕配置共用同一批 Bullet.tscn 实例。

## 所有弹幕数据共用同一个场景池。空闲上限不限制同时发射数量。
const BULLET_SCENE = preload("res://Scene/Bullet/Bullet.tscn")
## 启动时预先创建的空闲实例数量，实际数量受 max_idle_count 限制。
@export var prewarm_count: int = 128
## 最多保留的空闲实例数；并发发射不受此限制，池耗尽时按需创建。
@export var max_idle_count: int = 256

## 可复用的空闲节点栈：回收后入栈，发射时从末尾取出。
var _idle: Array[Node2D] = []
## 在用节点到所属游戏场景的映射，用于场景退出时定向回收。
var _active: Dictionary = {}


## 管理器入树后预热，减少首次大量发射时的实例化开销。
func _ready() -> void:
	prewarm(prewarm_count)


## 将空闲数量补足到 count（最多 max_idle_count），不是额外创建 count 个。
## 如果已有足够的空闲节点，则不执行任何操作。
func prewarm(count: int) -> void:
	while _idle.size() < mini(count, max_idle_count):
		_idle.append(_create_bullet())


## 创建并挂到管理器下；Bullet._ready() 会将新实例设为失活状态。
## 节点随 Autoload 保留，游戏场景切换不会直接销毁它们。
func _create_bullet() -> Node2D:
	var bullet = BULLET_SCENE.instantiate()
	add_child(bullet)
	return bullet


## 取出空闲实例或扩容，然后按资源数据激活，返回本次发射的节点。
## data：ElementaryBullet / SeniorBullet 资源；attacker：已入树的攻击者。
## origin：全局生成位置；direction：发射方向，由 Bullet.activate() 归一化。
## speed：每秒移动距离；target：可命中的目标分组名称。
## 数据为空或攻击者无效时返回 null；返回的节点回收后可能被其他发射复用。
func spawn(data: ElementaryBullet, attacker: BaseCharacter, origin: Vector2,
		direction: Vector2, speed: float = 500.0, target: String = "Enemy") -> Node2D:
	if data == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return null
	var bullet: Node2D = _idle.pop_back() if not _idle.is_empty() else _create_bullet()
	# 记录发射时的场景，而非攻击者作为父节点，避免攻击者销毁影响池。
	var scene := get_tree().current_scene
	_active[bullet] = scene
	# 同一场景只连接一次退出信号，退出时回收它对应的全部在用弹幕。
	if scene != null and not scene.tree_exiting.is_connected(_on_scene_exiting.bind(scene)):
		scene.tree_exiting.connect(_on_scene_exiting.bind(scene), CONNECT_ONE_SHOT)
	bullet.activate(data, attacker, origin, direction, speed, target)
	return bullet

## 立即失活，延迟入空闲队列，避免物理回调期间重新启用同一个碰撞体。
func recycle(bullet: Node2D) -> void:
	# 忽略重复回收和非本池在用节点，防止同一实例多次进入空闲队列。
	if not _active.has(bullet):
		return
	_active.erase(bullet)
	# 停止移动、计时和动画，使旧上下文失效，并延迟关闭碰撞。
	bullet.deactivate()
	_store_idle.call_deferred(bullet)


## 在延迟调用阶段完成回收；缓存满时释放多余实例，控制常驻内存。
func _store_idle(bullet: Node2D) -> void:
	if not is_instance_valid(bullet):
		return
	if _idle.size() >= max_idle_count:
		bullet.queue_free()
	else:
		_idle.append(bullet)


## 回收全部在用弹幕；节点进入空闲队列需等延迟调用完成。
## keys() 返回键列表，可在遍历时通过 recycle() 修改原字典。
func recycle_all() -> void:
	for bullet in _active.keys():
		recycle(bullet)


## 仅回收指定场景的弹幕，防止切换场景后旧弹幕继续运动或造成伤害。
func _on_scene_exiting(scene: Node) -> void:
	for bullet in _active.keys():
		if _active[bullet] == scene:
			recycle(bullet)


## 返回在用和空闲数量，便于调试及调整预热/缓存容量。
## 已失活但尚未完成延迟入队的节点，不计入这两个数量。
func get_stats() -> Dictionary:
	return {"active": _active.size(), "idle": _idle.size()}
