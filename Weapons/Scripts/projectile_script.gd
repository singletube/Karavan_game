extends RigidBody3D

class_name Projectile

#properties variables
var is_explosive : bool = false
var direction : Vector3 
var damage : float
var time_before_vanish : float 
var bodies_list : Array = []

#references variables
@onready var mesh = %Mesh
@onready var hitbox : CollisionShape3D = %Hitbox

@export_group("Sound variables")
@onready var audio_manager : PackedScene = preload("../../Misc/AudioManager/audio_manager_scene.tscn")
@export var explosion_sound : AudioStream

@export_group("Particles variables")
@onready var explosion_particle_effect : PackedScene = preload("../../Misc/ParticlesEffects/ExplosionParticleEffect/explosion_particle_effect_scene.tscn")

func _process(delta : float) -> void:
	if time_before_vanish > 0.0: time_before_vanish -= delta
	else: hit()
		
func _on_body_entered(body : Node3D) -> void:
	if body == self or body == get_parent():
		return
	if is_explosive:
		explode()
	else:
		apply_damage(body)
		hit()

func hit() -> void:
	mesh.visible = false
	hitbox.set_deferred("disabled", true)
	
	if is_explosive: explode()

func apply_damage(body : Node3D) -> void:
	var target := _find_damage_target(body)
	if target == null:
		return
	if target.has_method("take_damage"):
		if target.is_in_group("Enemies") or target.is_in_group("enemy"):
			target.call("take_damage", maxi(1, roundi(damage)), direction, body.global_position + Vector3.UP * 0.7)
		else:
			target.call("take_damage", maxi(1, roundi(damage)))
	elif target.has_method("projectile_hit"):
		target.call("projectile_hit", damage, direction)

func _find_damage_target(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.is_in_group("Enemies") or node.is_in_group("enemy") or node.is_in_group("HitableObjects"):
			return node
		if node.has_method("take_damage") or node.has_method("projectile_hit"):
			return node
		node = node.get_parent()
	return null
	
func explode() -> void:
	# Damage all enemies and players in blast radius before showing effects.
	var blast_radius := 8.0
	for group_name in ["enemy", "player"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if not target is Node3D or not is_instance_valid(target):
				continue
			if target == get_parent() or target.get("is_dead") == true:
				continue
			var distance: float = global_position.distance_to((target as Node3D).global_position)
			if distance <= blast_radius and target.has_method("take_damage"):
				var falloff: float = maxf(0.25, 1.0 - distance / blast_radius)
				target.call("take_damage", maxi(1, roundi(damage * falloff)), direction)

	sound_management(explosion_sound)
	
	var particles_ins : ExplosionParticleEffect = null
	if !particles_ins:
		particles_ins = explosion_particle_effect.instantiate()
		particles_ins.particle_to_emit = "Explosion"
		particles_ins.global_transform = global_transform
		get_tree().get_root().add_child.call_deferred(particles_ins)
		particles_ins.global_transform = global_transform
	else:
		print("Projectile already has emit explosion particles")
		
	queue_free()
	
func sound_management(sound : AudioStream) -> void:
	if sound != null:
		var audio_ins : AudioStreamPlayer3D = audio_manager.instantiate()
		audio_ins.global_transform = global_transform
		get_tree().get_root().add_child(audio_ins)
		audio_ins.bus = "Sfx"
		audio_ins.volume_db = 5.0
		audio_ins.stream = sound
		audio_ins.play()
