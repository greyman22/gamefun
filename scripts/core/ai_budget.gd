extends RefCounted
# Cooperative main-thread search budget: an individual search is atomic.
# Waiting requests age so distant creatures cannot starve behind nearby ones.
var active: bool=false
var last_game_time: float=-1
var max_searches: int=2
var time_budget_usec: int=1500
var searches: int=0
var spent_usec: int=0
var now: float=0
var revision: int=0
var pending: Dictionary={}
var total_searches: int=0
var total_deferred: int=0
func begin_frame(delta: float, game_time: float=-1) -> void:
	active=true
	last_game_time=game_time
	now+=delta
	searches=0
	spent_usec=0
	for key: String in pending.keys():
		if now-float(pending[key].seen)>0.2:
			pending.erase(key)
func invalidate(_cell: Vector3i) -> void:
	revision+=1
func request(key: String, priority: float) -> bool:
	if not pending.has(key):
		pending[key]={"since":now,"seen":now,"priority":priority}
	pending[key].seen=now
	pending[key].priority=priority
	if searches>=max_searches or spent_usec>=time_budget_usec:
		total_deferred+=1
		return false
	var score: float=priority+(now-float(pending[key].since))*40
	for other: String in pending:
		var candidate: Dictionary=pending[other]
		if other!=key and now-float(candidate.seen)<=0.2 and float(candidate.priority)+(now-float(candidate.since))*40>score:
			total_deferred+=1
			return false
	pending.erase(key)
	searches+=1
	total_searches+=1
	return true
func completed(usec: int) -> void:
	spent_usec+=usec

func ensure_frame(game_time: float) -> void:
	if active and last_game_time!=game_time:
		begin_frame(maxf(0,game_time-last_game_time),game_time)
