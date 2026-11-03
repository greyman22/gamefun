extends "res://scripts/berry_bush.gd"
const Cotton=preload("res://scripts/core/cotton.gd")
func refresh() -> void:
	if not is_instance_valid(visual):
		return
	var growth: int=Cotton.stage(record,model.game_time)
	var ready: bool=model.game_time>=float(record.ripe_at)
	if growth==shown_stage and ready==shown_ripe:
		return
	shown_stage=growth
	shown_ripe=ready
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	var height: float=[0.4,0.75,1.05,1.3][growth]
	collision.shape.size=Vector3(0.85,height+0.12,0.85)
	collision.position.y=height*0.5
	part(Vector3(0,height*0.5,0),Vector3(0.065,height,0.065),Color("755335"))
	for i in range(2+growth):
		var angle: float=i*2.4
		var point:=Vector3(cos(angle)*0.29,height*(0.35+i*0.12),sin(angle)*0.29)
		part(point,Vector3(0.36,0.085,0.23),Color("849b4c") if not ready else Color("315b27"))
		if not ready:
			# Raised, contrasting leaves and a pale growing tip distinguish seedlings from grass.
			part(point+Vector3(0,0.035,0),Vector3(0.07,0.055,0.25),Color("c0bc78"))
		if ready:
			var boll: Vector3=point+Vector3(0,0.15,0)
			part(boll,Vector3.ONE*0.32,Color("fff8e8"),true)
			part(boll+Vector3(0.1,0.05,0),Vector3.ONE*0.22,Color("f1eadb"),true)
			part(boll+Vector3(-0.07,0.08,0.06),Vector3.ONE*0.22,Color("fffbed"),true)

	if not ready:
		part(Vector3(0,height+0.025,0),Vector3(0.13,0.16,0.13),Color("c5cb87"),true)
