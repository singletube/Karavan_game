import bpy
import os
import time

def main():
    t_start = time.time()
    print("=== STARTING ZOMBIE CYBORG TEXTURE BAKE & EXPORT ===")

    blend_file = r"c:\Users\user\ZombieCyborg\zombie_cyborg.blend"
    bpy.ops.wm.open_mainfile(filepath=blend_file)

    proj_dir = r"c:\Users\user\Documents\идет-караван-из-ирана"
    tex_dir = os.path.join(proj_dir, "models", "zombies", "textures")
    os.makedirs(tex_dir, exist_ok=True)

    albedo_path = os.path.join(tex_dir, "zombie_cyborg_albedo.png")
    normal_path = os.path.join(tex_dir, "zombie_cyborg_normal.png")
    rough_path  = os.path.join(tex_dir, "zombie_cyborg_roughness.png")
    metal_path  = os.path.join(tex_dir, "zombie_cyborg_metallic.png")
    emit_path   = os.path.join(tex_dir, "zombie_cyborg_emission.png")
    export_glb_path = os.path.join(proj_dir, "models", "zombies", "zombie_cyborg.glb")

    obj = bpy.data.objects.get("Zombie_Cyborg")
    if not obj:
        raise RuntimeError("Zombie_Cyborg object not found in blend file!")

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # Remove Cornea duplicate hull faces before baking
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')

    mat_names = [m.name for m in obj.data.materials if m]
    if "Cornea" in mat_names:
        c_idx = mat_names.index("Cornea")
        for p in obj.data.polygons:
            if p.material_index == c_idx:
                p.select = True
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.delete(type='FACE')
        bpy.ops.object.mode_set(mode='OBJECT')
        print("Removed duplicate Cornea outer shell.")

    # Configure Cycles for fast bake
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.device = 'CPU'
    bpy.context.scene.cycles.samples = 1

    bake_size = 2048

    # Helper function to create bake target nodes across all active materials
    def setup_bake_node(node_name, img):
        for m in obj.data.materials:
            if m and m.node_tree:
                n = m.node_tree.nodes.new('ShaderNodeTexImage')
                n.name = node_name
                n.image = img
                m.node_tree.nodes.active = n
        return img

    def remove_bake_node(node_name):
        for m in obj.data.materials:
            if m and m.node_tree:
                n = m.node_tree.nodes.get(node_name)
                if n:
                    m.node_tree.nodes.remove(n)

    # 1. Bake Albedo (Diffuse Color)
    print("Baking 2048 Albedo...")
    img_albedo = bpy.data.images.new("Bake_Albedo", width=bake_size, height=bake_size)
    setup_bake_node("BAKE_ALBEDO", img_albedo)
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=8)
    img_albedo.filepath_raw = albedo_path
    img_albedo.file_format = 'PNG'
    img_albedo.save()
    remove_bake_node("BAKE_ALBEDO")
    print("Saved albedo to", albedo_path)

    # 2. Bake Normal
    print("Baking 2048 Normal...")
    img_normal = bpy.data.images.new("Bake_Normal", width=bake_size, height=bake_size)
    setup_bake_node("BAKE_NORMAL", img_normal)
    bpy.ops.object.bake(type='NORMAL', margin=8)
    img_normal.filepath_raw = normal_path
    img_normal.file_format = 'PNG'
    img_normal.save()
    remove_bake_node("BAKE_NORMAL")
    print("Saved normal to", normal_path)

    # 3. Bake Roughness
    print("Baking 2048 Roughness...")
    img_rough = bpy.data.images.new("Bake_Rough", width=bake_size, height=bake_size)
    setup_bake_node("BAKE_ROUGH", img_rough)
    bpy.ops.object.bake(type='ROUGHNESS', margin=8)
    img_rough.filepath_raw = rough_path
    img_rough.file_format = 'PNG'
    img_rough.save()
    remove_bake_node("BAKE_ROUGH")
    print("Saved roughness to", rough_path)

    # 4. Bake Emission
    print("Baking 2048 Emission...")
    img_emit = bpy.data.images.new("Bake_Emit", width=bake_size, height=bake_size)
    setup_bake_node("BAKE_EMIT", img_emit)
    bpy.ops.object.bake(type='EMIT', margin=8)
    img_emit.filepath_raw = emit_path
    img_emit.file_format = 'PNG'
    img_emit.save()
    remove_bake_node("BAKE_EMIT")
    print("Saved emission to", emit_path)

    # 5. Bake Metallic (via temporary emission sockets)
    print("Baking 2048 Metallic...")
    img_metal = bpy.data.images.new("Bake_Metal", width=bake_size, height=bake_size)
    temp_emit_nodes = []
    for m in obj.data.materials:
        if m and m.node_tree:
            bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            emit = m.node_tree.nodes.new('ShaderNodeEmission')
            temp_emit_nodes.append((m, emit))
            if bsdf:
                if bsdf.inputs['Metallic'].links:
                    m.node_tree.links.new(bsdf.inputs['Metallic'].links[0].from_socket, emit.inputs['Color'])
                else:
                    val = bsdf.inputs['Metallic'].default_value
                    emit.inputs['Color'].default_value = (val, val, val, 1.0)
            out = next((n for n in m.node_tree.nodes if n.type == 'OUTPUT_MATERIAL'), None)
            if out:
                m.node_tree.links.new(emit.outputs['Emission'], out.inputs['Surface'])
            n = m.node_tree.nodes.new('ShaderNodeTexImage')
            n.name = "BAKE_METAL"
            n.image = img_metal
            m.node_tree.nodes.active = n

    bpy.ops.object.bake(type='EMIT', margin=8)
    img_metal.filepath_raw = metal_path
    img_metal.file_format = 'PNG'
    img_metal.save()

    for m, emit in temp_emit_nodes:
        m.node_tree.nodes.remove(emit)
    remove_bake_node("BAKE_METAL")
    print("Saved metallic to", metal_path)

    # 6. Rebuild mesh materials into 1 unified optimized PBR material
    print("Assembling unified PBR material...")
    obj.data.materials.clear()

    mat_unified = bpy.data.materials.new(name="M_Zombie_Cyborg")
    mat_unified.use_nodes = True
    ntree = mat_unified.node_tree
    ntree.nodes.clear()

    out_node = ntree.nodes.new('ShaderNodeOutputMaterial')
    out_node.location = (600, 0)

    bsdf = ntree.nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (200, 0)
    ntree.links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])

    # Load textures
    tex_albedo = bpy.data.images.load(albedo_path)
    tex_normal = bpy.data.images.load(normal_path)
    tex_normal.colorspace_settings.name = 'Non-Color'
    tex_rough  = bpy.data.images.load(rough_path)
    tex_rough.colorspace_settings.name = 'Non-Color'
    tex_metal  = bpy.data.images.load(metal_path)
    tex_metal.colorspace_settings.name = 'Non-Color'
    tex_emit   = bpy.data.images.load(emit_path)

    # Node: Albedo
    node_alb = ntree.nodes.new('ShaderNodeTexImage')
    node_alb.image = tex_albedo
    node_alb.location = (-300, 250)
    ntree.links.new(node_alb.outputs['Color'], bsdf.inputs['Base Color'])

    # Node: Metallic
    node_met = ntree.nodes.new('ShaderNodeTexImage')
    node_met.image = tex_metal
    node_met.location = (-300, 0)
    ntree.links.new(node_met.outputs['Color'], bsdf.inputs['Metallic'])

    # Node: Roughness
    node_rgh = ntree.nodes.new('ShaderNodeTexImage')
    node_rgh.image = tex_rough
    node_rgh.location = (-300, -250)
    ntree.links.new(node_rgh.outputs['Color'], bsdf.inputs['Roughness'])

    # Node: Normal
    node_norm_tex = ntree.nodes.new('ShaderNodeTexImage')
    node_norm_tex.image = tex_normal
    node_norm_tex.location = (-300, -500)

    node_norm_map = ntree.nodes.new('ShaderNodeNormalMap')
    node_norm_map.location = (-50, -500)
    ntree.links.new(node_norm_tex.outputs['Color'], node_norm_map.inputs['Color'])
    ntree.links.new(node_norm_map.outputs['Normal'], bsdf.inputs['Normal'])

    # Node: Emission
    node_emi = ntree.nodes.new('ShaderNodeTexImage')
    node_emi.image = tex_emit
    node_emi.location = (-300, -750)
    ntree.links.new(node_emi.outputs['Color'], bsdf.inputs['Emission Color'])
    if 'Emission Strength' in bsdf.inputs:
        bsdf.inputs['Emission Strength'].default_value = 3.5

    obj.data.materials.append(mat_unified)
    # Ensure all polygons point to material index 0
    for p in obj.data.polygons:
        p.material_index = 0

    print("Unified material applied.")

    # 7. Export GLB
    print("Exporting GLB to", export_glb_path)
    bpy.ops.export_scene.gltf(
        filepath=export_glb_path,
        export_format='GLB',
        use_selection=False,
        export_animations=True,
        export_skins=True,
        export_morph=True,
        export_materials='EXPORT',
        export_image_format='AUTO',
        export_nla_strips=True,
        export_def_bones=True,
        export_optimize_animation_size=False
    )

    print("GLB export complete! Total time:", time.time() - t_start, "s")

if __name__ == "__main__":
    main()
