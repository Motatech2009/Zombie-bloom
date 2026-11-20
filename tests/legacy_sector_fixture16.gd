extends RefCounted
## Legacy tests exercise ordinary sectors. Special 1.6 encounters have their own suite.
static func normal(world: Node3D) -> void:
	for y in range(-3,4):
		for x in range(-3,4):
			if x==0 and y==0: continue
			world.exp16.sectors["%d:%d" % [x,y]] = {"kind":"normal","hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
