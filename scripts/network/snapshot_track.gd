class_name SnapshotTrack
extends RefCounted
const DELAY := .1
static func push(node: Node3D,point: Vector3,now: float) -> void:
	var samples: Array = node.get_meta("samples",[])
	if not samples.is_empty() and point.distance_to(samples[-1].p)>15: samples.clear(); node.position = point
	samples.append({"t":now,"p":point})
	while samples.size()>8: samples.pop_front()
	node.set_meta("samples",samples)

static func position_at(node: Node3D,now: float) -> Vector3:
	var samples: Array = node.get_meta("samples",[])
	if samples.is_empty(): return node.position
	var at := now-DELAY
	while samples.size()>2 and float(samples[1].t)<=at: samples.pop_front()
	if samples.size()<2 or at<float(samples[0].t): return samples[0].p
	var fraction := clampf((at-float(samples[0].t))/maxf(.001,float(samples[1].t)-float(samples[0].t)),0,1)
	return samples[0].p.lerp(samples[1].p,fraction)
