extends SceneTree


func _init() -> void:
	var packed := load("res://assets/models/trees/polyhaven_fir_sapling_medium_cc0/fir_sapling_medium_mobile.glb") as PackedScene
	if not packed:
		push_error("Unable to load fir asset")
		quit(1)
		return
	var instance := packed.instantiate()
	for child in instance.get_children():
		if child is MeshInstance3D and child.mesh:
			print("FIR_NODE=", child.name, " AABB=", child.mesh.get_aabb(), " SURFACES=", child.mesh.get_surface_count())
			for surface in range(child.mesh.get_surface_count()):
				var material: Material = child.mesh.surface_get_material(surface)
				print("  SURFACE=", surface, " MATERIAL=", material.resource_name, " CLASS=", material.get_class())
	instance.free()
	quit()
