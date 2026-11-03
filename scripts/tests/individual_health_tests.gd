extends SceneTree
const Combat=preload("res://scripts/core/combat.gd")
var failures: int=0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	seed(321)
	for kind in ["zombie","skeleton","hen","chick","sheep","lamb"]:
		var maximum: float=Combat.stats(kind).health
		var lowest: float=maximum
		var highest: float=0
		for i in range(100):
			var record: Dictionary={}
			var health: float=Combat.starting_health(record,kind)
			expect(health>=maximum*0.8 and health<=maximum,"New health is within bounds")
			lowest=minf(lowest,health)
			highest=maxf(highest,health)
			record.state.health=health*0.5
			expect(Combat.starting_health(record.duplicate(true),kind)==health*0.5,"Reactivation and saved copies preserve injury")
			if kind in ["chick","lamb"]:
				var adult: String="hen" if kind=="chick" else "sheep"
				expect(is_equal_approx(Combat.grown_health(record,adult)/float(Combat.stats(adult).health),record.health_factor),"Growth preserves individual variation")
		expect(highest-lowest>maximum*0.1,"Individuals have varied health")
	var old: Dictionary={"state":{"health":12.5}}
	expect(Combat.starting_health(old,"hen")==12.5,"Existing saved animals are untouched")
	print("INDIVIDUAL HEALTH TESTS ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
