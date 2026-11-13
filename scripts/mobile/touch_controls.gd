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
var floating_center := Vector2.ZERO
var interaction_text: String = ""
var move_origin := Vector2.ZERO
var move_dragged: bool = false
var context_left: float = 0
var explicit_target: bool = false
var locked_target: Node3D
var target_revision: int = -1
var target_slot: int = -1
var target_ammo: int = -1
const STICK_RADIUS: float = 72

func _ready() -> void:
	pad_style = UI.style(Color(.035,.075,.1,.08),Color(1,1,1,.38),38)
	pressed_style = UI.style(Color(.3,.42,.35,.45),Color.WHITE,38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self)
	build_target = world.player.position+world.player.aim*4
	resized.connect(layout_controls)
	layout_controls()

func layout_controls() -> void:
	building_layout = is_instance_valid(world) and is_instance_valid(world.builder) and world.builder.active
	buttons = {"actions":Rect2(14,154,68,54),"inventory":Rect2(14,218,68,54),"roll":Rect2(size.x-100,size.y-310,76,64),"reload":Rect2(size.x-252,size.y-180,76,58),"pause":Rect2(size.x-68,106,54,44),"fire":Rect2(size.x-142,size.y-202,118,118)}
	if not interaction_text.is_empty() or interact_held: buttons.interact = Rect2(size.x-230,size.y-310,116,64)
	if is_instance_valid(world) and is_instance_valid(world.builder) and world.builder.active:
		buttons.erase("roll"); buttons.erase("interact"); buttons.erase("reload"); buttons.erase("fire")
		buttons.merge({"rotate":Rect2(size.x-310,size.y-208,92,64),"place":Rect2(size.x-208,size.y-208,184,72),"cancel":Rect2(size.x-208,size.y-126,184,58)})
	queue_redraw()

func stick_center(role: String) -> Vector2:
	return floating_center if role=="move" and floating_center!=Vector2.ZERO else Vector2(110 if role=="move" else size.x-110,size.y-140)

func reset_fingers() -> void:
	fingers.clear(); floating_center = Vector2.ZERO; move_vector = Vector2.ZERO; fire_held = false; launcher_spent = false; interact_held = false; reload_held = false
	clear_target()
	queue_redraw()

func frame() -> Dictionary:
	var movement_aim: Vector3 = world.player.movement_direction(move_vector).normalized() if move_vector.length_squared()>.01 else world.player.aim
	var input := {"move":move_vector,"aim":movement_aim,"sprint":move_vector.length()>.88,"fire":false,"reload":reload_held,"interact":interact_held,"slot":world.pending_slot if world.is_client and world.pending_slot>=0 else world.player.bag.selected}
	if (target_revision>=0 and target_revision!=scene_token()) or (target_slot>=0 and target_slot!=world.player.bag.selected) or world.builder.active or world.player.health.dead or not world.hud.mode.is_empty(): fire_held = false
	if not MobileTargeting.alive(locked_target) or target_revision!=scene_token() or target_slot!=world.player.bag.selected or world.builder.active or world.player.health.dead or not world.hud.mode.is_empty():
		clear_target()
	if target_ammo>=0 and world.player.weapons.ammo[4]<target_ammo: launcher_spent = true; clear_target()
	if is_instance_valid(locked_target):
		var point := MobileTargeting.point(locked_target)
		if world.camera.is_position_behind(point) or not Rect2(Vector2.ZERO,size).has_point(world.camera.unproject_position(point)):
			clear_target(); return input
		if fire_held:
			input.aim = MobileTargeting.direction(world.player,locked_target)
			input.fire = not interact_held and target_shootable
			input.target = {"id":locked_target.net_id,"rev":target_revision}
	return input

func scene_token() -> int:
	return world.last_scene_revision if world.is_client else world.scene_revision

func clear_target() -> void:
	explicit_target = false; locked_target = null; target_revision = -1; target_slot = -1; target_ammo = -1; target_shootable = false

func world_touch_allowed(point: Vector2) -> bool:
	if point.y<112 or not Rect2(Vector2.ZERO,size).has_point(point) or world.hud.belt.get_global_rect().has_point(point): return false
	if fingers.values().has("move") and point.distance_to(stick_center("move"))<=92: return false
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
		explicit_target = true

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
			if fingers.has(event.index):
				var tap: bool = fingers[event.index]=="move" and not move_dragged and not fire_held and not event.canceled
				release_finger(event.index)
				if tap: select_target(event.position)
				get_viewport().set_input_as_handled()
			return
		var role := ""
		for key in buttons:
			if buttons[key].has_point(event.position): role = key; break
		if role.is_empty() and event.position.x<size.x*.5 and world_touch_allowed(event.position) and not world.builder.active and not fingers.values().has("move"):
			role = "move"
			move_origin = event.position; move_dragged = false
			floating_center = event.position
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
		if role=="move":
			move_dragged = move_dragged or event.position.distance_to(move_origin)>8
			drag_stick(role,event.position)
		elif role=="fire" and not buttons.fire.grow(24).has_point(event.position): release_finger(event.index)
		get_viewport().set_input_as_handled()

func drag_stick(role: String,point: Vector2) -> void:
	var vector := ((point-stick_center(role))/STICK_RADIUS).limit_length(1)
	if role=="move": move_vector = Vector2.ZERO if vector.length()<.15 else vector.normalized()*((vector.length()-.15)/.85)
	queue_redraw()

func release_finger(index: int) -> void:
	var role: String = fingers.get(index,"")
	fingers.erase(index)
	if role=="move": move_vector = Vector2.ZERO; floating_center = Vector2.ZERO
	elif role=="fire": fire_held = false; launcher_spent = false
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
	context_left -= delta
	if context_left<=0:
		context_left = .1
		var hint: String = world.remote_interaction_hint if world.is_client else world.interaction_hint(world.player)
		if hint!=interaction_text: interaction_text = hint; layout_controls()
	assist_left -= delta; refresh_left -= delta
	if fire_held and not launcher_spent and assist_left<=0 and not world.builder.active:
		assist_left = .12
		if not MobileTargeting.alive(locked_target) or (not explicit_target and not target_shootable): assist_target()
	if refresh_left<=0: refresh_left = .1; refresh_target()
	if building_layout!=world.builder.active: layout_controls()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset_fingers()

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.hud) or not world.hud.mode.is_empty() or world.phase=="ended": return
	var center := stick_center("move")
	draw_circle(center,STICK_RADIUS,Color(.04,.10,.13,.10))
	draw_arc(center,STICK_RADIUS,0,TAU,40,Color(1,1,1,.4),2,true)
	draw_circle(center+move_vector*STICK_RADIUS*.65,24,Color(1,1,1,.9 if fingers.values().has("move") else .35))

	if MobileTargeting.alive(locked_target) and not world.camera.is_position_behind(MobileTargeting.point(locked_target)):
		var target_center: Vector2 = world.camera.unproject_position(MobileTargeting.point(locked_target))
		var color := UI.LIME if target_shootable else Color("efb66d")
		for angle in range(4): draw_arc(target_center,27,angle*PI/2+.15,angle*PI/2+1.15,12,color,3,true)
		var title := "ALVO" if color==UI.LIME else "SEM TIRO"
		draw_string(ThemeDB.fallback_font,target_center+Vector2(-45,-36),title,HORIZONTAL_ALIGNMENT_CENTER,90,12,color)
	var names := {"actions":"AÇÕES","inventory":"BOLSA","roll":"ROLAR","interact":interaction_text if not interaction_text.is_empty() else "COLETAR","reload":"RECARGA","pause":"Ⅱ","rotate":"GIRAR","place":"COLOCAR","cancel":"CANCELAR","fire":"ATIRAR"}
	for role in buttons:
		var rect: Rect2 = buttons[role]
		var active := fingers.values().has(role)
		draw_style_box(pressed_style if active else pad_style,rect)
		var text: String = names[role]
		var tint := Color(1,1,1,1 if active else .4)
		if role=="fire":
			if world.player.bag.hand()=="grenade": text = "LANÇAR\nGRANADA"
			elif world.player.bag.hand()=="medkit": text = "USAR\nKIT"
			elif fire_held: text = "ATIRANDO" if target_shootable else "SEM ALVO"
		if role=="roll" and world.player.roll_cooldown>0: text = "ROLAR\n%.1f s" % world.player.roll_cooldown
		var icons := {"actions":"☰","inventory":"▣","roll":"↻","interact":"↓","reload":"↺"}
		if icons.has(role): draw_string(ThemeDB.fallback_font,rect.position+Vector2(0,27),icons[role],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,25,tint)
		var rows := text.split("\n")
		if role=="fire":
			var icon := rect.get_center()-Vector2(0,23)
			draw_arc(icon,13,0,TAU,24,Color.WHITE if fire_held else Color(1,1,1,.4),2,true)
			for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(icon+axis*9,icon+axis*19,tint,2,true)
		for i in range(rows.size()): draw_string(ThemeDB.fallback_font,rect.position+Vector2(3,rect.size.y*.5+17+(i-(rows.size()-1)*.5)*18),rows[i],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-6,24 if role=="pause" else 17 if role=="fire" else 13,tint)

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
