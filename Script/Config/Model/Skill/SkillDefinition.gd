class_name SkillDefinition
extends Resource

enum Kind { ACQUIRED, ONE_TIME, CONTINUOUS, INSTANT }

@export var id: StringName
## 技能界面展示图标，可在 .tres 中配置；未配置时为 null。
@export var icon: Texture2D
@export var kind: Kind = Kind.ACQUIRED
## 条件来源路径相对人物，例如 InputController:dash_pressed；获得性属性能力可留空。
@export var trigger: NodePath
@export var cooldown: float = 0.0
@export var duration: float = 0.0
@export var animation: StringName
@export var cancel_on_state_change := false
## 只记录请求的转化事件，目标状态由各状态的 NextStates 定义。
@export var control_event: StringName
@export var acquire_effects: Array[SkillEffect] = []
@export var effects: Array[SkillEffect] = []
@export var finish_effects: Array[SkillEffect] = []

func can_execute(context: SkillContext) -> bool:
	for effect in effects:
		if effect == null or not effect.can_execute(context):
			return false
	return true

func apply_acquired(context: SkillContext) -> void:
	for effect in acquire_effects:
		effect.execute(context)

func revoke_acquired(context: SkillContext) -> void:
	for effect in acquire_effects:
		effect.remove(context)

func execute(context: SkillContext) -> void:
	if control_event != &"":
		context.caster.skill_control_requested.emit(control_event)
	for effect in effects:
		if context.cancelled:
			return
		effect.execute(context)

func finish(context: SkillContext) -> void:
	for effect in finish_effects:
		effect.execute(context)

func should_finish(context: SkillContext) -> bool:
	for effect in effects:
		if effect.should_finish(context):
			return true
	return false
