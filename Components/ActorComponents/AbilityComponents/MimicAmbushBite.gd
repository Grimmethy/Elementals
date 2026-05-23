class_name MimicAmbushBite
extends AbilityAction

const BITE_RANGE: float = 2.3
const PIERCE_DAMAGE: float = 7.0
const ACID_DAMAGE: float = 4.0
const STUN_DURATION: float = 1.25
const COOLDOWN: float = 6.0

var _cooldown_left: float = 0.0

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Adhesive Bite"
	ability_description = "Savage bite that deals piercing + acid and briefly disables the target."
	ability_usage = "Press R when an enemy is close."

func can_execute(type: String) -> bool:
	return type == "ability_r" and _cooldown_left <= 0.0 and actor != null and not actor.is_dead

func execute(type: String, _value = null) -> void:
	if not can_execute(type):
		return
	var body: Node = actor.get_node_or_null("Body")
	if body and body.has_method("trigger_bite"):
		body.call("trigger_bite")
	var target: Actor = _find_nearest_bite_target()
	if target == null:
		_emit_message("No target in Ambush Bite range.")
		return
	var dir: Vector3 = (target.global_position - actor.global_position).normalized()
	# Grappler trait (D&D 5e Mimic): advantage on attacks against a creature
	# the mimic is grappling. We simulate "advantage" on the damage roll by
	# rolling twice and taking the higher — applied here as a bite-damage
	# crit-multiplier when the target carries our grapple meta.
	var has_grappler: bool = bool(actor.get_meta("grappler_advantage", false))
	var target_is_glued: bool = bool(target.get_meta("grappled_by_mimic", false))
	var pierce_damage: float = PIERCE_DAMAGE
	var acid_damage: float = ACID_DAMAGE
	if has_grappler and target_is_glued:
		# Roll twice (advantage proxy) and apply the higher multiplier.
		var roll_a: float = randf_range(1.0, 1.5)
		var roll_b: float = randf_range(1.0, 1.5)
		var mult: float = maxf(roll_a, roll_b)
		pierce_damage *= mult
		acid_damage *= mult
		_emit_message("%s bites %s with Grappler advantage!" % [actor.name, target.name])
	target.take_damage(pierce_damage, "piercing", dir)
	target.take_damage(acid_damage, "acid", dir)
	if target.has_method("stun"):
		target.stun(STUN_DURATION)
	_cooldown_left = COOLDOWN
	_emit_message("%s used Ambush Bite on %s." % [actor.name, target.name])

func update(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

func _find_nearest_bite_target() -> Actor:
	if actor == null:
		return null
	var arena_value: Variant = actor.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return null
	var arena: ArenaGrid = arena_value as ArenaGrid
	var nearest: Actor = null
	var nearest_distance: float = INF
	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var candidate: Actor = node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		if actor.has_method("is_enemy") and not actor.is_enemy(candidate):
			continue
		var flat_dist: float = Vector2(
			candidate.global_position.x - actor.global_position.x,
			candidate.global_position.z - actor.global_position.z
		).length()
		if flat_dist > BITE_RANGE:
			continue
		if flat_dist < nearest_distance:
			nearest_distance = flat_dist
			nearest = candidate
	return nearest

func _emit_message(text: String) -> void:
	print("[Mimic] ", text)
	if actor and actor.get_node_or_null("/root/QuestEvents"):
		QuestEvents.message(text)
