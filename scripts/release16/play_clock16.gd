class_name PlayClock16
extends RefCounted
var total := 0.0
var session := 0.0
var longest := 0.0
var idle := 0.0
var last_ms := -1
var focused := true
var afk := false
func step(now_ms: int,eligible: bool,activity: bool = false) -> float:
	var delta := clampf((now_ms-last_ms)*.001,0,2) if last_ms>=0 else 0.0
	last_ms = now_ms
	if activity: idle = 0
	else: idle += delta
	afk = idle>=float(Catalog16.data().afk_seconds)
	if not eligible or not focused or afk: return 0
	total += delta; session += delta; longest = maxf(longest,session)
	return delta
static func display(seconds: float) -> String:
	var minutes := int(maxf(0,seconds))/60
	return "%dh %02dmin" % [minutes/60,minutes%60]
