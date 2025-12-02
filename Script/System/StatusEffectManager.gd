extends Node

#class Index:
	#var target: BaseCharacter
	#var status_name: ENUM.STATUS
	#
	#func _init(Target: BaseCharacter, StatusName: ENUM.STATUS):
		#self.target =  Target
		#self.status_name = StatusName

var StatusTimer: Dictionary[String, Timer]

##设置状态计时器
func set_status_timer(index: String):
	if !StatusTimer.has(index):
		StatusTimer[index] = Timer.new()
		StatusTimer[index].one_shot = true
		add_child(StatusTimer[index])

func enhance_health(Target:BaseCharacter, Duration:float):
	#检测非法情况
	if !Target || Duration <= 0:
		return

	#在目标状态栏中添加状态
	Target.add_new_status(ENUM.STATUS.EnhanceHealth, Duration)
	
	var index:String = Target.name+"status"+str(ENUM.STATUS.EnhanceHealth)
	set_status_timer(index)
	
	#施加效果
	var current:float
	if StatusTimer[index].is_stopped():
		current = Target.get_character_max_health()
		Target.set_character_max_health(current+1000)
	
	StatusTimer[index].start(Duration)
	
	#持续时间结束后移除计时器和效果
	await StatusTimer[index].timeout
	StatusTimer.erase(index)
	current = Target.get_character_max_health()
	Target.set_character_max_health(current-1000)

#func _physics_process(delta: float) -> void:
	#if StatusTimer.get(_index):
		#print(StatusTimer[_index].time_left)
		#pass
