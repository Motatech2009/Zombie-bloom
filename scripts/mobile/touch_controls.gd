class_name TouchControls
extends Control
var world: Node3D
var fingers: Dictionary = {}
var move_vector := Vector2.ZERO
var fire_held: bool = false
var free_aim := Vector3.FORWARD
var target_shootable: bool = false
var assist_left: float = 0
var refresh_left: float = 0
var launcher_spent: bool = false
var interact_held: bool = false
var reload_held: bool = false
var build_target := Vector3.ZERO
var buttons: Dictionary = {}
var pad_style: StyleBoxFlat
var pressed_style: StyleBoxFlat
var building_layout: bool = false
var locked_target: Node3D
var target_revision: int = -1
var target_slot: int = -1
var target_ammo: int = -1
const STICK_RADIUS: float = 72

func _ready() -> void:
	pad_style = UI.style(Color(.035,.075,.1,.86),Color("9dba83"),12)
	pressed_style = UI.style(Color("405b50"),Color("9dba83"),12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self)
	build_target = world.player.position+world.player.aim*4
	resized.connect(layout_controls)
	layout_controls()

func layout_controls() -> void:
	building_layout = is_instance_valid(world) and is_instance_valid(world.builder) and world.builder.active
	buttons = {"actions":Rect2(20,size.y-330,76,62),"inventory":Rect2(104,size.y-330,76,62),"roll":Rect2(size.x-118,size.y-330,98,72),"interact":Rect2(size.x-220,size.y-306,100,74),"reload":Rect2(size.x-300,size.y-190,82,64),"pause":Rect2(size.x-82,103,66,48),"fire":Rect2(size.x-192,size.y-218,168,146)}
	if is_instance_valid(world) and is_instance_valid(world.builder) and world.builder.active:
		buttons.erase("roll"); buttons.erase("interact"); buttons.erase("reload"); buttons.erase("fire")
		buttons.merge({"rotate":Rect2(size.x-310,size.y-208,92,64),"place":Rect2(size.x-208,size.y-208,184,72),"cancel":Rect2(size.x-208,size.y-126,184,58)})
	queue_redraw()

func stick_center(role: String) -> Vector2:
	return Vector2(110 if role=="move" else size.x-110,size.y-140)

func reset_fingers() -> void:
	fingers.clear(); move_vector = Vector2.ZERO; fire_held = false; launcher_spent = false; interact_held = false; reload_held = false
	clear_target()
	queue_redraw()

func frame() -> Dictionary:
	var input := {"move":move_vector,"aim":free_aim,"sprint":move_vector.length()>.88,"fire":false,"reload":reload_held,"interact":interact_held,"slot":world.pending_slot if world.is_client and world.pending_slot>=0 else world.player.bag.selected}
	if (target_revision>=0 and target_revision!=scene_token()) or (target_slot>=0 and target_slot!=world.player.bag.selected) or world.builder.active or world.player.health.dead or not world.hud.mode.is_empty(): fire_held = false
	if not MobileTargeting.alive(locked_target) or target_revision!=scene_token() or target_slot!=world.player.bag.selected or world.builder.active or world.player.health.dead or not world.hud.mode.is_empty():
		clear_target()
	if target_ammo>=0 and world.player.weapons.ammo[4]<target_ammo: launcher_spent = true; clear_target()
	if is_instance_valid(locked_target):
		var point := MobileTargeting.point(locked_target)
		if world.camera.is_position_behind(point) or not Rect2(Vector2.ZERO,size).has_point(world.camera.unproject_position(point)):
			clear_target(); return input
		input.aim = MobileTargeting.direction(world.player,locked_target)
		input.fire = not interact_held and target_shootable
		input.target = {"id":locked_target.net_id,"rev":target_revision}
	return input

func scene_token() -> int:
	return world.last_scene_revision if world.is_client else world.scene_revision

func clear_target() -> void:
	locked_target = null; target_revision = -1; target_slot = -1; target_ammo = -1; target_shootable = false

func world_touch_allowed(point: Vector2) -> bool:
	if point.y<112 or not Rect2(Vector2.ZERO,size).has_point(point) or world.hud.belt.get_global_rect().has_point(point): return false
	if point.distance_to(stick_center("move"))<=92: return false
	for rect in buttons.values():
		if rect.has_point(point): return false
	return true

func select_target(point: Vector2) -> void:
	fire_held = false
	clear_target()
	if ItemBag.WEAPON_IDS.find(world.player.bag.hand())<0:
		var hit = Plane(Vector3.UP,0).intersects_ray(world.camera.project_ray_origin(point),world.camera.project_ray_normal(point))
		if hit!=null: free_aim = ((hit-world.player.position)*Vector3(1,0,1)).normalized()
		return
	var best := 38.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not MobileTargeting.alive(enemy) or world.camera.is_position_behind(MobileTargeting.point(enemy)): continue
		var target_center: Vector2 = world.camera.unproject_position(MobileTargeting.point(enemy))
		var feet: Vector2 = world.camera.unproject_position(enemy.global_position)
		var distance := Geometry2D.get_closest_point_to_segment(point,feet,target_center).distance_to(point)
		if distance>=best: continue
		best = distance; locked_target = enemy
	if locked_target!=null:
		set_target(locked_target)

	queue_redraw()

func _input(event: InputEvent) -> void:
	# --touch on desktop is a one-finger simulator; Android uses native multitouch.
	if not OS.has_feature("mobile") and MobilePlatform.enabled():
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=InputEvent.DEVICE_ID_EMULATION:
			var finger := InputEventScreenTouch.new(); finger.index = 0; finger.pressed = event.pressed; finger.position = event.position
			_input(finger); return
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and event.device!=InputEvent.DEVICE_ID_EMULATION:
			var finger := InputEventScreenDrag.new(); finger.index = 0; finger.position = event.position
			_input(finger); return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
	if not world.hud.mode.is_empty() or world.phase=="ended": reset_fingers(); return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.canceled: clear_target()
			if fingers.has(event.index): release_finger(event.index); get_viewport().set_input_as_handled()
			return
		var role := ""
		for key in buttons:
			if buttons[key].has_point(event.position): role = key; break
		if role.is_empty() and event.position.distance_to(stick_center("move"))<=92: role = "move"
		if role.is_empty() and world.builder.active:
			set_build_point(event.position); get_viewport().set_input_as_handled(); return
		if role.is_empty():
			# Leave the hotbar and top HUD to the GUI, even over a zombie.
			if not world_touch_allowed(event.position): return
			select_target(event.position); fingers[event.index] = "target"
			get_viewport().set_input_as_handled(); return
		if role.is_empty() or fingers.values().has(role): return
		fingers[event.index] = role
		if role=="interact": fire_held = false; clear_target()
		if role=="move": drag_stick(role,event.position)
		elif role=="interact": interact_held = true; travel_press()
		elif role=="reload": reload_held = true
		elif role=="fire": start_fire()
		else: trigger(role)
		get_viewport().set_input_as_handled()
	elif fingers.has(event.index):
		var role: String = fingers[event.index]
		if role=="move": drag_stick(role,event.position)
		elif role=="fire" and not buttons.fire.grow(24).has_point(event.position): release_finger(event.index)
		get_viewport().set_input_as_handled()

func drag_stick(role: String,point: Vector2) -> void:
	var vector := ((point-stick_center(role))/STICK_RADIUS).limit_length(1)
	if role=="move": move_vector = Vector2.ZERO if vector.length()<.15 else vector.normalized()*((vector.length()-.15)/.85)
	queue_redraw()

func release_finger(index: int) -> void:
	var role: String = fingers.get(index,"")
	fingers.erase(index)
	if role=="move": move_vector = Vector2.ZERO
	elif role=="fire": fire_held = false; launcher_spent = false; clear_target()
	elif role=="interact": interact_held = false
	elif role=="reload": reload_held = false
	queue_redraw()

func set_build_point(point: Vector2) -> void:
	var hit = Plane(Vector3.UP,0).intersects_ray(world.camera.project_ray_origin(point),world.camera.project_ray_normal(point))
	if hit!=null: build_target = Vector3(snappedf(hit.x,1),0,snappedf(hit.z,1))

func travel_press() -> void:
	for i in range(4):
		if world.local_player().distance_to(SectorGenerator.EXITS[i])<3.7:
			world.send_action("travel",{"direction":i}); return

func trigger(role: String) -> void:
	match role:
		"roll":
			var direction: Vector3 = world.player.movement_direction(move_vector).normalized() if move_vector.length_squared()>.01 else frame().aim
			world.send_action("roll",{"direction":direction})
		"inventory": reset_fingers(); world.hud.show_inventory()
		"actions": reset_fingers(); world.hud.show_actions()
		"pause": reset_fingers(); world.hud.show_pause()
		"rotate": world.builder.angle = fposmod(world.builder.angle+PI/2,TAU)
		"place": world.builder.location = build_target; world.builder.place()
		"cancel": world.builder.set_active(false)

func _process(delta: float) -> void:
	if not world.hud.mode.is_empty() or world.phase=="ended": reset_fingers()
	if world.builder.active: clear_target()
	assist_left -= delta; refresh_left -= delta
	if fire_held and not launcher_spent and assist_left<=0 and not world.builder.active:
		assist_left = .12
		if not MobileTargeting.alive(locked_target) or not target_shootable: assist_target()
	if refresh_left<=0: refresh_left = .1; refresh_target()
	if building_layout!=world.builder.active: layout_controls()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset_fingers()

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.hud) or not world.hud.mode.is_empty() or world.phase=="ended": return
	var center := stick_center("move")
	draw_circle(center,STICK_RADIUS,Color(.04,.10,.13,.70))
	draw_arc(center,STICK_RADIUS,0,TAU,40,Color("82aaa7"),2,true)
	draw_circle(center+move_vector*STICK_RADIUS*.65,26,Color("c7e58a"))
	draw_string(ThemeDB.fallback_font,center+Vector2(-60,STICK_RADIUS+20),"MOVER",HORIZONTAL_ALIGNMENT_CENTER,120,12,UI.TEXT)
	if MobileTargeting.alive(locked_target) and not world.camera.is_position_behind(MobileTargeting.point(locked_target)):
		var target_center: Vector2 = world.camera.unproject_position(MobileTargeting.point(locked_target))
		var color := UI.LIME if target_shootable else Color("efb66d")
		for angle in range(4): draw_arc(target_center,27,angle*PI/2+.15,angle*PI/2+1.15,12,color,3,true)
		var title := "ALVO" if color==UI.LIME else "SEM TIRO"
		draw_string(ThemeDB.fallback_font,target_center+Vector2(-45,-36),title,HORIZONTAL_ALIGNMENT_CENTER,90,12,color)
	var names := {"actions":"AÇÕES","inventory":"BOLSA","roll":"ROLAR","interact":"SEGURE\nCOLETAR","reload":"RECARGA","pause":"Ⅱ","rotate":"GIRAR","place":"COLOCAR","cancel":"CANCELAR","fire":"SEGURE\nATIRAR"}
	for role in buttons:
		var rect: Rect2 = buttons[role]
		var active := fingers.values().has(role)
		draw_style_box(pressed_style if active else pad_style,rect)
		var text: String = names[role]
		if role=="fire":
			if world.player.bag.hand()=="grenade": text = "LANÇAR\nGRANADA"
			elif world.player.bag.hand()=="medkit": text = "USAR\nKIT"
			elif fire_held: text = "ATIRANDO" if target_shootable else "SEM ALVO"
		if role=="roll" and world.player.roll_cooldown>0: text = "ROLAR\n%.1f s" % world.player.roll_cooldown
		var rows := text.split("\n")
		if role=="fire":
			var icon := rect.get_center()-Vector2(0,33)
			draw_arc(icon,13,0,TAU,24,UI.LIME if fire_held else UI.TEXT,2,true)
			for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(icon+axis*9,icon+axis*19,UI.TEXT,2,true)
		for i in range(rows.size()): draw_string(ThemeDB.fallback_font,rect.position+Vector2(3,rect.size.y*.5+5+(i-(rows.size()-1)*.5)*18),rows[i],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-6,24 if role=="pause" else 17 if role=="fire" else 13,UI.LIME if role=="roll" and world.player.roll_cooldown==0 else UI.TEXT)

func set_target(enemy: Node3D) -> void:
	locked_target = enemy; target_revision = scene_token(); target_slot = world.player.bag.selected
	if world.player.bag.hand()=="launcher": target_ammo = world.player.weapons.ammo[4]
	refresh_target()

func refresh_target() -> void:
	target_shootable = MobileTargeting.alive(locked_target) and MobileTargeting.can_fire(world.player,locked_target)

func assist_target() -> void:
	if ItemBag.WEAPON_IDS.find(world.player.bag.hand())<0: return
	var candidates: Array = []
	var weapon: int = ItemBag.WEAPON_IDS.find(world.player.bag.hand())
	var range_squared: float = pow(float(Arsenal.WEAPONS[weapon].values.range),2)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not MobileTargeting.alive(enemy): continue
		var distance: float = enemy.position.distance_squared_to(world.player.position)
		if distance>range_squared or world.camera.is_position_behind(MobileTargeting.point(enemy)): continue
		if not Rect2(Vector2.ZERO,size).has_point(world.camera.unproject_position(MobileTargeting.point(enemy))): continue
		candidates.append({"enemy":enemy,"distance":distance})
	candidates.sort_custom(func(a,b): return a.distance<b.distance)
	# Bound cover queries in a dense crowd; never fire blindly to find a target.
	for candidate in candidates.slice(0,6):
		if MobileTargeting.can_fire(world.player,candidate.enemy): set_target(candidate.enemy); return
	clear_target()

func start_fire() -> void:
	launcher_spent = false
	if world.player.bag.hand() in ["grenade","medkit"]:
		clear_target()
		world.send_action("consume",{"slot":world.player.bag.selected,"aim":free_aim})
		return
	fire_held = true; assist_left = .12
	if not MobileTargeting.alive(locked_target): assist_target()
	else: refresh_target()
