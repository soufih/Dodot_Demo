extends BaseCharacter


func _ready() -> void:
	super.Beginning()
	add_to_group("Hero")

func _physics_process(delta: float) -> void:
	super.Running()
