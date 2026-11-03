extends RefCounted

signal damaged(amount: float)
signal died
var passive_elapsed: float = 0
var fed_elapsed: float = 0
var health: float = 100
var satiety: float = 100
var protection: float = 0
var air: float=10
var submerged: bool=false

func damage(amount: float, source: String = "fall") -> float:
	if health <= 0 or amount <= 0 or (source == "zombie" and protection > 0):
		return 0
	var taken: float = minf(health, amount)
	health -= taken
	damaged.emit(taken)
	if source == "zombie":
		protection = 0.8
	if health <= 0:
		died.emit()
	return taken

static func fall_damage(height: float) -> float:
	return 20.0 * maxf(0, snappedf(height, 0.01) - 2.0)

func tick(delta: float) -> void:
	protection = maxf(0, protection - delta)
	if health <= 0:
		return
	if health >= 100:
		passive_elapsed = 0
		fed_elapsed = 0
		return
	passive_elapsed += delta
	if satiety >= 95:
		fed_elapsed += delta
		while fed_elapsed >= 5 and satiety >= 95 and health < 100:
			fed_elapsed -= 5
			health = minf(100, health + 20)
			satiety -= 5
	else:
		fed_elapsed = 0
	while passive_elapsed >= 60:
		passive_elapsed -= 60
		health = minf(100, health + 5)
	if satiety < 95 or health >= 100:
		fed_elapsed = 0
	if health >= 100:
		passive_elapsed = 0

func reset() -> void:
	air=10
	submerged=false
	health = 100
	satiety = 100
	protection = 2
	passive_elapsed = 0
	fed_elapsed = 0

func snapshot() -> Dictionary:
	return {"air":air,"health": health, "satiety": satiety, "protection": protection, "passive_elapsed": passive_elapsed, "fed_elapsed": fed_elapsed}

func restore(state: Dictionary) -> void:
	air=clampf(float(state.get("air",10)),0,10)
	health = clampf(float(state.get("health", 100)), 0, 100)
	satiety = clampf(float(state.get("satiety", 100)), 0, 100)
	protection = clampf(float(state.get("protection", 0)), 0, 2)

	passive_elapsed = clampf(float(state.get("passive_elapsed", 0)), 0, 60)
	fed_elapsed = clampf(float(state.get("fed_elapsed", 0)), 0, 5)

func breathe(delta: float, underwater: bool) -> void:
	submerged=underwater
	if health<=0:
		return
	if underwater:
		air=maxf(0,air-delta)
		if air<=0:
			damage(health,"drowning")
	else:
		air=minf(10,air+delta*(10.0/3.0))
