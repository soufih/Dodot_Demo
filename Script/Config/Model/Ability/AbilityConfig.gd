class_name AbilityConfig
extends Resource

@export var id: StringName
@export var display_name: String
@export var ico: Texture2D

@export_group("Lifecycle")
@export var cooldown: float = 0.0
@export var durationL: float

@export_group("Rules")
@export var tags: Array[StringName] = []
@export var blocked_by_tags: Array[StringName] = []
@export var cancelable_by_tags: Array[StringName] = []

@export_group("Input")
@export var input_action: Array[StringName] = []

@export_group("Instance")
@export var instance: Script
