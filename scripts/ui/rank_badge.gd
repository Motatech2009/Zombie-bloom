class_name RankBadge
extends Control
## Layered rounded shapes, raised clay rims, recessed centre and moulded stars.
var level := 0:
	set(value): level = clampi(value,0,10); queue_redraw()
func _init() -> void:
	custom_minimum_size = Vector2(76,82); mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var centre := size*.5
	var unit := minf(size.x,size.y)*.40
	var color := Color("82979f") if level<4 else Color("e9ae4e") if level<7 else Color("ae79d4") if level<10 else Color("efb8d2")
	if level==0: color = Color("586b69")
	var shield := PackedVector2Array()
	for p in [Vector2(-.7,-.86),Vector2(.7,-.86),Vector2(.95,.1),Vector2(0,1),Vector2(-.95,.1)]: shield.append(centre+p*unit)
	var shadow := shield.duplicate()
	for i in range(shadow.size()): shadow[i] += Vector2(0,5)
	draw_colored_polygon(shadow,Color(0,0,0,.38))
	if level>=4:
		for side in [-1,1]:
			for row in range(3): draw_line(centre+Vector2(side*unit*.75,unit*(-.55+row*.24)),centre+Vector2(side*unit*(1.32-row*.1),unit*(-.7+row*.24)),color.darkened(.15),unit*.15,true)
	draw_colored_polygon(shield,color.darkened(.35))
	var inner := PackedVector2Array()
	for point in shield: inner.append(centre+(point-centre)*.75)
	draw_colored_polygon(inner,Color("213e40"))
	var outline := shield.duplicate(); outline.append(shield[0])
	draw_polyline(outline,color,unit*.14,true)
	for point in shield: draw_circle(point,unit*.07,color,true,-1,true)
	draw_line(shield[0]+Vector2(3,3),shield[1]+Vector2(-3,3),color.lightened(.35),unit*.07,true)
	if level==0:
		draw_circle(centre,unit*.18,color.darkened(.1))
	elif level<4:
		for row in range(maxi(1,level)):
			var y := unit*(-.35+row*.32)
			draw_polyline(PackedVector2Array([centre+Vector2(-unit*.4,y),centre+Vector2(0,y+unit*.22),centre+Vector2(unit*.4,y)]),color.lightened(.22),unit*.12,true)
	else:
		var stars := 1+(level-4)%3
		for i in range(stars):
			var points := PackedVector2Array(); var offset := Vector2((i-(stars-1)*.5)*unit*.47,0)
			for n in range(10): points.append(centre+offset+Vector2(sin(n*PI/5),-cos(n*PI/5))*unit*(.3 if n%2==0 else .14))
			draw_colored_polygon(points,color.lightened(.25))
	if level>0: draw_string(ThemeDB.fallback_font,centre+Vector2(-unit*.12,unit*.75),str(level),HORIZONTAL_ALIGNMENT_LEFT,-1,int(unit*.4),color.lightened(.4))
