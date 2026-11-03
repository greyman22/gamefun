extends RefCounted

# Main-thread measurements only; worker generation is included in streaming latency,
# not misreported as main-thread CPU time.
static var active: bool = false
static var started: int = 0
static var previous_frame: int = 0
static var metrics: Dictionary = {}
static var frame_bins: Dictionary = {}
static var frames: int = 0
static var frame_total: float = 0
static var frame_max: float = 0
static var slow_frames: Array = []
static var samples: Array = []
static var next_sample: int = 0
static var last_path: String = ""

static func start() -> void:
	metrics.clear()
	frame_bins.clear()
	slow_frames.clear()
	samples.clear()
	frames=0
	frame_total=0
	frame_max=0
	started=Time.get_ticks_usec()
	previous_frame=0
	next_sample=started
	active=true

static func begin() -> int:
	return Time.get_ticks_usec() if active else 0

static func finish(label: String, stamp: int) -> void:
	if not active or stamp==0:
		return
	var ms: float=(Time.get_ticks_usec()-stamp)/1000.0
	var value: Dictionary=metrics.get(label,{"calls":0,"total_ms":0.0,"max_ms":0.0})
	value.calls+=1
	value.total_ms+=ms
	value.max_ms=maxf(value.max_ms,ms)
	metrics[label]=value

static func frame(context: Dictionary) -> void:
	if not active:
		return
	var now: int=Time.get_ticks_usec()
	if previous_frame>0:
		var ms: float=(now-previous_frame)/1000.0
		frames+=1
		frame_total+=ms
		frame_max=maxf(frame_max,ms)
		var bucket: int=ceili(ms)
		frame_bins[bucket]=int(frame_bins.get(bucket,0))+1
		if ms>50 and slow_frames.size()<500:
			slow_frames.append({"second":(now-started)/1000000.0,"frame_ms":ms,"context":context.duplicate(true)})
	previous_frame=now
	if now>=next_sample and samples.size()<3600:
		next_sample=now+1000000
		context=context.duplicate(true)
		context["second"]=(now-started)/1000000.0
		context["fps"]=Performance.get_monitor(Performance.TIME_FPS)
		context["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		context["physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		context["draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		context["primitives"]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		context["objects"]=Performance.get_monitor(Performance.OBJECT_COUNT)
		context["memory_bytes"]=Performance.get_monitor(Performance.MEMORY_STATIC)
		context["activity_totals"]=metrics.duplicate(true)
		samples.append(context)

static func stop() -> String:
	active=false
	var rows: Dictionary=metrics.duplicate(true)
	for label: String in rows:
		rows[label]["average_ms"]=rows[label].total_ms/maxi(1,rows[label].calls)
	var p95: int=0
	var cumulative: int=0
	var keys: Array=frame_bins.keys()
	keys.sort()
	for key: int in keys:
		cumulative+=frame_bins[key]
		if cumulative>=frames*0.95:
			p95=key
			break
	var report: Dictionary={"format_version":1,"created":Time.get_datetime_string_from_system(),"godot":Engine.get_version_info().string,"os":OS.get_name(),"duration_seconds":(Time.get_ticks_usec()-started)/1000000.0,"frames":frames,"average_frame_ms":frame_total/maxi(1,frames),"p95_frame_ms":p95,"max_frame_ms":frame_max,"activities":rows,"samples":samples,"slow_frames":slow_frames,"notes":"Activity timings overlap: do not add parent and child timings. Frame time includes waiting/rendering; GPU time is not measured. Slow frames capped at 500; one-second samples capped at 3600."}
	DirAccess.make_dir_recursive_absolute("user://performance")
	var path: String="user://performance/measurement-%s-%d.json"%[Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_msec()]
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		return ""
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	last_path=ProjectSettings.globalize_path(path)
	return last_path
