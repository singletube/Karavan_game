extends Node3D

var current_weapon : WeaponSlot
var point_of_collision : Vector3 = Vector3.ZERO
var rng : RandomNumberGenerator

@onready var weapon_manager : Node3D = %WeaponManager

func get_current_weapon(current_weapon_ref : WeaponSlot) -> void:
	#get current weapon resources
	current_weapon = current_weapon_ref
	
func shoot() -> void:
	if !current_weapon.resources.is_shooting and (
	#magazine isn't empty, and has >= ammo than the number of projectiles required for a shot
	(current_weapon.resources.total_ammo_in_mag > 0 and current_weapon.resources.total_ammo_in_mag >= current_weapon.resources.nb_proj_shots_at_same_time)
	or 
	#has all ammos in the magazine, and number of ammo is positive
	(current_weapon.resources.all_ammo_in_mag and weapon_manager.ammo_manager.ammo_dict[current_weapon.resources.ammo_type] > 0 and \
	#has >= ammo than the number of projectiles required for a shot
	weapon_manager.ammo_manager.ammo_dict[current_weapon.resources.ammo_type] >= current_weapon.resources.nb_proj_shots_at_same_time)
	) and !current_weapon.resources.is_reloading:
		current_weapon.resources.is_shooting = true
		if current_weapon.resources.weapon_name == "Chainsaw":
			var m: Node = current_weapon.model.get_node_or_null("ChainsawModel")
			if m and m.has_method("set_sawing"):
				m.set_sawing(true)
		
		#number of successive shots (for example if 3, the weapon will shot 3 times in a row)
		for i in range(current_weapon.resources.nb_proj_shots):
			#same conditions has before, are checked before every shot
			if ((current_weapon.resources.total_ammo_in_mag > 0 and current_weapon.resources.total_ammo_in_mag >= current_weapon.resources.nb_proj_shots_at_same_time) 
			or (current_weapon.resources.all_ammo_in_mag and weapon_manager.ammo_manager.ammo_dict[current_weapon.resources.ammo_type] > 0) and \
			weapon_manager.ammo_manager.ammo_dict[current_weapon.resources.ammo_type] >= current_weapon.resources.nb_proj_shots_at_same_time):
				
				weapon_manager.weapon_sound_management(current_weapon.resources.shoot_sound, current_weapon.resources.shoot_sound_speed)
				
				if current_weapon.resources.shoot_anim_name != "":
					weapon_manager.anim_manager.play_animation("ShootAnim%s" % current_weapon.resources.weapon_name, current_weapon.resources.shoot_anim_speed, true)
				else:
					print("%s doesn't have a shoot animation" % current_weapon.resources.weapon_name)
					
				#number projectiles shots at the same time (for example, 
				#a shotgun shell is constituted of ~ 20 pellets that are spread across the target, 
				#so 20 projectiles shots at the same time)
				for j in range(0, current_weapon.resources.nb_proj_shots_at_same_time):
					if current_weapon.resources.all_ammo_in_mag: weapon_manager.ammo_manager.ammo_dict[current_weapon.resources.ammo_type] -= 1
					else: current_weapon.resources.total_ammo_in_mag -= 1
					
					#get the collision point
					point_of_collision = get_camera_fov()
					
					#call the fonction corresponding to the selected type
					if current_weapon.resources.type == current_weapon.resources.TYPES.HITSCAN: hitscan_shot(point_of_collision)
					elif current_weapon.resources.type == current_weapon.resources.TYPES.PROJECTILE: projectile_shot(point_of_collision)
					
				var player := weapon_manager.get_parent()
				if player.has_method("play_legacy_muzzle_flash"):
					player.play_legacy_muzzle_flash(current_weapon.muzzle_flash_spawner.global_transform)
				elif current_weapon.resources.show_muzzle_flash:
					weapon_manager.display_muzzle_flash()
				
				weapon_manager.camera_recoil_holder.set_recoil_values(current_weapon.resources.base_rot_speed, current_weapon.resources.target_rot_speed)
				weapon_manager.camera_recoil_holder.add_recoil(current_weapon.resources.recoil_val)
				
				await get_tree().create_timer(current_weapon.resources.time_between_shots).timeout
				
			else:
				print("Not enought ammunitions to shoot")
				
		if current_weapon.resources.weapon_name == "Chainsaw":
			var m: Node = current_weapon.model.get_node_or_null("ChainsawModel")
			if m and m.has_method("set_sawing"):
				m.set_sawing(false)
		current_weapon.resources.is_shooting = false
		
func get_camera_fov() -> Vector3:  
	var camera : Camera3D = %Camera
	# Use the actual camera viewport, not the window size: viewport stretch and
	# embedded viewports otherwise offset the ray from the screen-center crosshair.
	var viewport_center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	var raycast_start : Vector3 = camera.project_ray_origin(viewport_center)
	var raycast_end : Vector3 = Vector3.ZERO
	var ray_length: float = current_weapon.resources.max_range if current_weapon.resources.type == current_weapon.resources.TYPES.HITSCAN else 280.0
	raycast_end = raycast_start + camera.project_ray_normal(viewport_center) * ray_length
	
	#Create intersection space to contain possible collisions 
	var new_intersection : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(raycast_start, raycast_end)
	new_intersection.exclude = [weapon_manager.get_parent().get_rid()]
	var intersection : Dictionary = get_world_3d().direct_space_state.intersect_ray(new_intersection)
	
	#If the raycast has collide with something, return collision point transform properties
	if !intersection.is_empty():
		var collision_point : Vector3 = intersection.position
		return collision_point 
	#Else, return the end of the raycast (so nothing, because he hasn't collide with anything) 
	else:
		return raycast_end 
		
func hitscan_shot(point_of_collision_hitscan : Vector3) -> void:
	var camera: Camera3D = %Camera
	# The hit ray must be the same ray used to find the crosshair's collision point.
	# Applying a second random spread here made impacts drift away from the reticle.
	var origin: Vector3 = camera.project_ray_origin(camera.get_viewport().get_visible_rect().size * 0.5)
	var direction: Vector3 = (point_of_collision_hitscan - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * current_weapon.resources.max_range)
	query.exclude = [weapon_manager.get_parent().get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	var target: Node = _find_damage_target(collider)
	if target != null:
		var damage_scale := 1.0
		if collider is Node and (collider as Node).is_in_group("EnemiesHead"):
			damage_scale = current_weapon.resources.headshot_damage_mult
		var distance_ratio := clampf(origin.distance_to(hit.position) / maxf(current_weapon.resources.max_range, 1.0), 0.0, 1.0)
		var damage_curve: Curve = current_weapon.resources.damage_dropoff
		var dropoff := damage_curve.sample(distance_ratio) if damage_curve else 1.0
		var damage := maxf(1.0, current_weapon.resources.damage_per_proj * damage_scale * dropoff)
		if target.is_in_group("HitableObjects"):
			damage /= 6.0
		if target.has_method("take_damage"):
			if target.is_in_group("Enemies") or target.is_in_group("enemy"):
				target.call("take_damage", maxi(1, roundi(damage)), direction, hit.position)
				if current_weapon.resources.weapon_name == "Chainsaw":
					_spawn_chainsaw_blood(hit.position)
					if weapon_manager.hud and weapon_manager.hud.has_method("add_screen_blood_splatter"):
						weapon_manager.hud.add_screen_blood_splatter(randi_range(2, 4))
			else:
				target.call("take_damage", maxi(1, roundi(damage)))
		elif target.has_method("hitscan_hit"):
			target.call("hitscan_hit", damage, direction, hit.position)
			if current_weapon.resources.weapon_name == "Chainsaw":
				_spawn_chainsaw_blood(hit.position)
				if weapon_manager.hud and weapon_manager.hud.has_method("add_screen_blood_splatter"):
					weapon_manager.hud.add_screen_blood_splatter(randi_range(2, 4))
	elif collider is Node and (collider as Node).is_in_group("HitableObjects") and collider.has_method("hitscan_hit"):
		var distance_ratio := clampf(origin.distance_to(hit.position) / maxf(current_weapon.resources.max_range, 1.0), 0.0, 1.0)
		var damage_curve: Curve = current_weapon.resources.damage_dropoff
		var dropoff := damage_curve.sample(distance_ratio) if damage_curve else 1.0
		(collider as Node).call("hitscan_hit", current_weapon.resources.damage_per_proj * dropoff / 6.0, direction, hit.position)
	if not (collider is Node and ((collider as Node).is_in_group("Enemies") or (collider as Node).is_in_group("EnemiesHead"))):
		weapon_manager.display_bullet_hole(hit.position, hit.normal)

func _spawn_chainsaw_blood(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "ChainsawBloodSpray"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 54
	p.lifetime = 0.65
	p.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	p.spread = 180.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 4.5
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -11.0, 0.0)
	p.color = Color(0.85, 0.012, 0.03, 1.0)
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.0

	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color(0.85, 0.012, 0.03, 1.0)
	droplet_material.roughness = 0.3
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.035
	droplet_mesh.height = 0.07
	droplet_mesh.material = droplet_material
	p.mesh = droplet_mesh

	get_tree().get_root().add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true

	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _find_damage_target(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.is_in_group("Enemies") or node.is_in_group("enemy") or node.is_in_group("HitableObjects"):
			return node
		if node.has_method("take_damage") or node.has_method("hitscan_hit"):
			return node
		node = node.get_parent()
	return null
			
func projectile_shot(point_of_collision_projectile : Vector3) -> void:
	# Aim from the muzzle through the point found by the camera-center ray.
	# This makes the projectile converge on the crosshair instead of flying off at
	# an unrelated world-axis spread offset.
	var muzzle_origin: Vector3 = current_weapon.attack_point.global_position
	var projectile_direction: Vector3 = (point_of_collision_projectile - muzzle_origin).normalized()
	
	#Instantiate projectile
	var proj_ins : Projectile = current_weapon.resources.proj_ref.instantiate()
	
	#set projectile properties
	proj_ins.global_transform = current_weapon.attack_point.global_transform
	proj_ins.direction = projectile_direction
	proj_ins.damage = current_weapon.resources.damage_per_proj
	proj_ins.time_before_vanish = current_weapon.resources.proj_time_before_vanish
	proj_ins.gravity_scale = current_weapon.resources.proj_gravity_val
	proj_ins.is_explosive = current_weapon.resources.is_proj_explosive
	
	get_tree().get_root().add_child(proj_ins)
	
	proj_ins.set_linear_velocity(projectile_direction * current_weapon.resources.proj_move_speed)
