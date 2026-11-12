class_name BetaTime
extends Node
var world: Node3D
var seconds: float = 8 * 120
const DAY := 48.0 * 60.0
var weather: float = .15
var lantern_on: bool = false
var lantern: OmniLight3D

func _ready() -> void:
	lantern = OmniLight3D.new()
	lantern.light_color = Color("efd9a4")
	lantern.omni_range = 14
	lantern.light_energy = 3
	world.player.add_child(lantern)
	lantern.position.y = 2

func day() -> int:
	return floori(seconds / DAY) + 1

func hour() -> float:
	return fmod(seconds / 120.0, 24)

func _process(delta: float) -> void:
	seconds += delta
	apply(delta)

func apply(delta: float = 1) -> void:
	world.get_viewport().scaling_3d_scale = BetaOptions.render_scale
	var h := hour()
	var sunlight := clampf(sin((h - 6) / 12 * PI), 0, 1)
	var sun: DirectionalLight3D = world.sunlight
	sun.rotation_degrees.x = -15 - sunlight * 55
	sun.light_energy = .08 + sunlight * 1.15
	sun.light_color = Color("efb47a").lerp(Color("d5e6db"), sunlight)
	var env: Environment = world.environment.environment
	env.ambient_light_energy = .16 + sunlight * .55
	env.ambient_light_color = Color("6280a0").lerp(Color("a3bdac"), sunlight)
	var slice := floori(seconds / 210)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.state.world_seed ^ (slice * 7193)
	var target := rng.randf()
	var outdoors_pos: Vector3 = world.return_position if world.inside else world.player.position
	if world.outdoor.generator.river_distance(Vector2(outdoors_pos.x, outdoors_pos.z)) < 22:
		target = minf(1, target + .2)
	weather = lerpf(weather, target, minf(1, delta * .08))
	# Standard depth fog works with the Compatibility renderer; volumetric fog is unnecessary.
	env.fog_enabled = not world.inside and BetaOptions.fog_strength > 0
	env.fog_light_color = Color("91a39a").lerp(Color("30475d"), 1 - sunlight)
	env.fog_density = (.001 + weather * .016) * BetaOptions.fog_strength
	env.fog_sky_affect = 0
	lantern.visible = lantern_on and world.inventory.count("lantern") > 0
	world.sunlight.shadow_enabled = BetaOptions.shadows

func weather_name() -> String:
	return "Céu limpo" if BetaOptions.fog_strength == 0 or weather < .2 else "Névoa leve" if weather < .5 else "Névoa moderada" if weather < .8 else "Névoa densa"
