class_name AbilityController
extends Node

@export var abilities_catalog: AbilityCatalog
@export var input_controller: InputController

var abilities: Dictionary = {}
var active_abilities: Array[AbilityInstance]= []
var context: AbilityContext
var _signalbus := SignalBus
var util: Util

@onready var motor: Node
@export var state_machine: Node


func _ready() -> void:
	_signalbus.ability_granted.connect(grant_ability)

	var _context := AbilityContext.new(
		owner,
		state_machine
	)

	setup(_context)
	
	grant_ability(owner, "dash")


func setup(ctx: AbilityContext) -> void:
	context = ctx


func grant_ability(player: Node2D, ability_id: StringName) -> bool:
	var ability:AbilityConfig = abilities_catalog.abilities.get(&"dash")
	if not ability:
		return false
	
	var instance:AbilityInstance = ability.instance.new(ability)
	if not ability:
		return false
	
	return register_ability(ability_id, instance)


func register_ability(
	ability_id: StringName,
	instance: AbilityInstance
) -> bool:
	if abilities.has(ability_id):
		var warning:= "Ability already registered: %s" % ability_id
		push_warning(warning)
		_signalbus.ability_granted_failed.emit(owner, warning)
		return false

	abilities[ability_id] = instance
	return true


func get_ability(
	ability_id: StringName
) -> AbilityInstance:
	return abilities.get(ability_id) as AbilityInstance


func request_activate(ability_id: StringName) -> bool:
	var ability :AbilityInstance = get_ability(ability_id)
	if ability == null:
		return false

	if not ability.can_activate(context):
		return false
		
	if has_blocked_tag(ability):
		return false

	ability.activate(context)

	if ability.state == AbilityInstance.State.ACTIVE:
		active_abilities.append(ability)

	return true


func has_blocked_tag(_ability: AbilityInstance) -> bool:
	var tags = _ability.get_data().tags
	for ability in active_abilities:
		if util.has_intersection(ability.get_data().blocked_by_tags, tags):
			return true
	return false


func request_cancel(
	ability_id: StringName,
	reason: StringName = &"cancelled"
) -> void:
	var ability := get_ability(ability_id)

	if ability != null:
		ability.interrupt(reason)


func _physics_process(delta: float) -> void:
	# 更新全部能力，以便冷却中的能力也能恢复。
	for ability in abilities.values():
		ability.tick(delta)

	# 清理已结束的活动能力。
	active_abilities = active_abilities.filter(
		func(a: AbilityInstance) -> bool:
			return a.state == AbilityInstance.State.ACTIVE
	)
