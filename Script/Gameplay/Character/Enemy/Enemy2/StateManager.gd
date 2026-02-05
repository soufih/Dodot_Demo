extends BaseEnemyStateManager

@export var Hatebox:Area2D
@export var HateTimer:Timer

var Dead:bool = false
var Moving:bool = false
var Breaked:bool = false

func check():
	if Dead || Breaked:
		return
		
	if Entity.CurrentHealth <= 0:
		Dead = true
		change_state(4)
		return
	
	if Entity.Toughness <= 0:
		Breaked = true
		change_state(3)
		return
		
	if Hatebox.has_overlapping_bodies():
		for body in Hatebox.get_overlapping_bodies():
			if body.is_in_group("Hero") && Current.name != "Trace":
				change_state(3)
				HateTimer.start(5)
				return

	if HateTimer.is_stopped() && Current.name != "Potrol":
		change_state(2)
		return


func _on_break(i: bool) -> void:
	Breaked = i
