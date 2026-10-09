"""The stone kit's shared workshop (R3.3, issue #660), for Blender's Python.

Every kind is made the same way, from its own recipe (`outcrops.py`,
`cliffs.py`, `ruins.py`):

1. **Sculpt.** Masses (rounded blocks, extruded layers) fused into one solid
   by a voxel remesh, joint planes cut through it, the remesh run again to
   weather the cuts, then displaced vertex by vertex: Voronoi cracks along the
   joints, a slow swell, a fine grain and level joint grooves
   (`mathutils.noise`, seeded per kind).
2. **Retopologise.** A copy of the sculpt reduced by quadric collapse to the
   kind's triangle budget, shaded smooth and unwrapped, its islands fitted to
   its own cell of the family's atlas.
3. **Bake** (Cycles, CPU, a fixed thread count): the sculpt's tangent-space
   normals, its ambient occlusion and its colour (the stone picture
   box-projected, darkened in its cavities, lifted on its edges) into that
   cell. The colour carries the occlusion; the normals are kept at half size.
4. **Export.** The reduced mesh as a Y-up GLB with a plain material named for
   its kind (the game paints it), and the master `.blend` (the reduced mesh,
   its recipe as custom properties) in `tools/map_atelier/journey/sources/`.

Deterministic for a given Blender: every random draw is seeded per kind.
"""
from pathlib import Path
import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "assets/art/map-journey/stone"
MASTERS = ROOT / "tools/map_atelier/journey/sources"
GLB = ROOT / "tools/map_atelier/journey/stone/glb"
IMPOSTOR_SOURCES = ROOT / "tools/map_atelier/journey/impostors/stone"
BUILD = ROOT / "build/stone"
THREADS = 4


def setup():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = THREADS
    scene.cycles.samples = 1
    scene.cycles.use_denoising = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Bake world")
    scene.world.light_settings.distance = 0.8


def reset():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.materials):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    # The view layer keeps stale entries for removed objects until it updates.
    bpy.context.view_layer.update()


def _deselect_all():
    for other in bpy.context.view_layer.objects:
        if other is not None:
            other.select_set(False)


def _activate(obj):
    _deselect_all()
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifiers(obj):
    _activate(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def mesh_object(name, verts, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def block(name, size, at, rotation=(0.0, 0.0, 0.0), round_share=0.22, segments=3):
    """A box `size` (x, y, z) at `at`, turned by `rotation` (radians, XYZ), its
    edges rounded by `round_share` of its least side."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if round_share > 0.0:
        bevel = obj.modifiers.new("Round", "BEVEL")
        bevel.width = round_share * min(size)
        bevel.segments = segments
        bevel.limit_method = "NONE"
        apply_modifiers(obj)
    return place(obj, at, rotation)


def prism(name, outline, low, high):
    """A solid extruded from the closed, anticlockwise XY `outline` between
    heights `low` and `high`."""
    count = len(outline)
    verts = [(x, y, low) for x, y in outline] + [(x, y, high) for x, y in outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, 2 * count))]
    for i in range(count):
        n = (i + 1) % count
        faces.append((i, n, n + count, i + count))
    return mesh_object(name, verts, faces)


def slab(name, outline, thickness):
    """A solid extruded from the closed, anticlockwise XZ `outline` (as seen
    from -Y, the front) through `thickness` along Y, centred on y = 0."""
    count = len(outline)
    half = thickness * 0.5
    verts = [(x, -half, z) for x, z in outline] + [(x, half, z) for x, z in outline]
    faces = [tuple(range(count)), tuple(range(2 * count - 1, count - 1, -1))]
    for i in range(count):
        n = (i + 1) % count
        faces.append((i, i + count, n + count, n))
    obj = mesh_object(name, verts, faces)
    _activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def place(obj, at=(0.0, 0.0, 0.0), rotation=(0.0, 0.0, 0.0)):
    """Turns `obj` (radians, XYZ) about its origin and moves it to `at`, both
    applied to its mesh."""
    obj.matrix_world = Matrix.Translation(Vector(at)) @ Matrix.Rotation(rotation[2], 4, "Z") \
        @ Matrix.Rotation(rotation[1], 4, "Y") @ Matrix.Rotation(rotation[0], 4, "X")
    _activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def torus(name, major, minor, at, rotation):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24,
        minor_segments=8)
    obj = bpy.context.object
    obj.name = name
    return place(obj, at, rotation)


def join(objects, name):
    _deselect_all()
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def remesh(obj, voxel):
    modifier = obj.modifiers.new("Fuse", "REMESH")
    modifier.mode = "VOXEL"
    modifier.voxel_size = voxel
    modifier.adaptivity = 0.0
    apply_modifiers(obj)


def smooth(obj, factor=0.5, repeat=2):
    modifier = obj.modifiers.new("Weather", "SMOOTH")
    modifier.factor = factor
    modifier.iterations = repeat
    apply_modifiers(obj)


def cut(obj, planes):
    """Cuts `obj` by each plane (a point, and the normal of the side taken
    away) and closes the cut: a joint face."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for point, normal in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(point),
            plane_no=Vector(normal).normalized(), clear_outer=True)
        edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_valid]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def boolean(obj, cutter, operation="DIFFERENCE"):
    modifier = obj.modifiers.new("Carve", "BOOLEAN")
    modifier.operation = operation
    modifier.object = cutter
    modifier.solver = "EXACT"
    apply_modifiers(obj)
    bpy.data.objects.remove(cutter, do_unlink=True)


def displace(obj, seed, cracks=(0.0, 1.0, 0.04), swell=(0.0, 0.6), grain=(0.0, 0.08),
        squash=(1.0, 1.0, 1.0), joints=(), joint=(0.0, 0.03)):
    """Moves every vertex along its normal: Voronoi cracks (`depth`, cells a
    metre, crack width in cell units), a slow swell (`height`, metres a wave),
    a fine grain (`height`, metres a wave), and a groove (`depth`, half-width)
    at each of `joints` (heights). `squash` scales the noise's space per axis
    (strata: wide, flat cells and upright cracks)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    offset = Vector((seed * 7.31 % 97.0, seed * 3.17 % 89.0, seed * 5.71 % 83.0))
    crack_depth, crack_cells, crack_width = cracks
    swell_height, swell_wave = swell
    grain_height, grain_wave = grain
    joint_depth, joint_width = joint
    for vert in bm.verts:
        p = Vector((vert.co.x * squash[0], vert.co.y * squash[1], vert.co.z * squash[2])) + offset
        move = 0.0
        if crack_depth > 0.0:
            distances, _ = noise.voronoi(p * crack_cells, distance_metric="DISTANCE")
            gap = distances[1] - distances[0]
            edge = max(0.0, 1.0 - gap / crack_width)
            move -= crack_depth * edge * edge
        if swell_height > 0.0:
            move += swell_height * noise.fractal(p / swell_wave, 0.8, 2.0, 3)
        if grain_height > 0.0:
            move += grain_height * noise.noise(p / grain_wave)
        for height in joints:
            # Only the faces that stand: a ledge's top keeps its level.
            upright = 1.0 - abs(vert.normal.z)
            move -= joint_depth * upright * math.exp(-((vert.co.z - height) / joint_width) ** 2)
        vert.co += vert.normal * move
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def retopologise(high, budget, name):
    """A copy of `high` collapsed to within `budget` (least, most) triangles."""
    target = (budget[0] + budget[1]) * 0.5
    ratio = target / max(1, triangles(high))
    for _ in range(8):
        trial = high.copy()
        trial.data = high.data.copy()
        bpy.context.scene.collection.objects.link(trial)
        modifier = trial.modifiers.new("Retopology", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = min(1.0, ratio)
        modifier.use_collapse_triangulate = True
        apply_modifiers(trial)
        count = triangles(trial)
        if budget[0] <= count <= budget[1]:
            trial.name = name
            for polygon in trial.data.polygons:
                polygon.use_smooth = True
            return trial
        ratio *= target / max(1, count)
        bpy.data.objects.remove(trial, do_unlink=True)
    raise AssertionError((name, "no reduction within", budget))


def unwrap(obj, cell=(0.0, 0.0, 1.0, 1.0), margin=0.02):
    """Unwraps `obj` and fits its islands into `cell` (u, v, width, height
    of the atlas, 0 to 1)."""
    _activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=margin,
        area_weight=1.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    u, v, width, height = cell
    for loop in obj.data.uv_layers.active.data:
        loop.uv = (u + loop.uv.x * width, v + loop.uv.y * height)


def _socket(sockets, identifier):
    """A node's socket by its identifier (the Mix node's float, vector and
    colour sockets share their names)."""
    return next(s for s in sockets if s.identifier == identifier)


def paint_material(name, picture, tile_m, cavity=0.5, edge=0.25, moss=None):
    """The sculpt's colour for the bake: `picture` box-projected in object
    space at `tile_m` metres a tile, darkened in cavities and lifted on edges
    (Cycles' pointiness), and where `moss` is (colour, how far up a face must
    turn), moss on what faces the sky."""
    material = bpy.data.materials.new(name)
    if hasattr(material, "use_nodes"):
        material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / tile_m,) * 3
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(picture), check_existing=True)
    texture.projection = "BOX"
    texture.projection_blend = 0.3
    links.new(mapping.outputs["Vector"], texture.inputs["Vector"])
    geometry = nodes.new("ShaderNodeNewGeometry")
    ramp = nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.42
    ramp.inputs["From Max"].default_value = 0.58
    ramp.inputs["To Min"].default_value = 1.0 - cavity
    ramp.inputs["To Max"].default_value = 1.0 + edge
    links.new(geometry.outputs["Pointiness"], ramp.inputs["Value"])
    shade = nodes.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    _socket(shade.inputs, "Factor_Float").default_value = 1.0
    links.new(texture.outputs["Color"], _socket(shade.inputs, "A_Color"))
    links.new(ramp.outputs["Result"], _socket(shade.inputs, "B_Color"))
    colour = _socket(shade.outputs, "Result_Color")
    if moss is not None:
        tint, rise = moss
        up = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geometry.outputs["Normal"], up.inputs["Vector"])
        cover = nodes.new("ShaderNodeMapRange")
        cover.inputs["From Min"].default_value = rise
        cover.inputs["From Max"].default_value = rise + 0.2
        links.new(up.outputs["Z"], cover.inputs["Value"])
        blotch = nodes.new("ShaderNodeTexNoise")
        blotch.inputs["Scale"].default_value = 3.0
        links.new(coords.outputs["Object"], blotch.inputs["Vector"])
        both = nodes.new("ShaderNodeMath")
        both.operation = "MULTIPLY"
        links.new(cover.outputs["Result"], both.inputs[0])
        links.new(blotch.outputs["Fac"], both.inputs[1])
        sharpen = nodes.new("ShaderNodeMapRange")
        sharpen.inputs["From Min"].default_value = 0.25
        sharpen.inputs["From Max"].default_value = 0.45
        links.new(both.outputs["Value"], sharpen.inputs["Value"])
        green = nodes.new("ShaderNodeMix")
        green.data_type = "RGBA"
        _socket(green.inputs, "B_Color").default_value = (*tint, 1.0)
        links.new(sharpen.outputs["Result"], _socket(green.inputs, "Factor_Float"))
        links.new(colour, _socket(green.inputs, "A_Color"))
        colour = _socket(green.outputs, "Result_Color")
    links.new(colour, shader.inputs["Base Color"])
    return material


def atlas(name, size):
    """The images a family bakes into, `size` (width, height): its normals,
    occlusion and colour."""
    images = {}
    for key, colour in (("normal", False), ("ao", False), ("colour", True)):
        image = bpy.data.images.new("%s-%s" % (name, key), size[0], size[1], alpha=False, float_buffer=False)
        image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        images[key] = image
    return images


def _target(low, image):
    """The reduced mesh's bake target: one material whose active node is
    `image`."""
    material = bpy.data.materials.new(low.name + " bake")
    if hasattr(material, "use_nodes"):
        material.use_nodes = True
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    material.node_tree.nodes.active = node
    low.data.materials.clear()
    low.data.materials.append(material)


def _bake(high, low, kind, image, reach, clear, samples=1, passes=None):
    _target(low, image)
    bpy.context.scene.cycles.samples = samples
    _deselect_all()
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    kwargs = dict(type=kind, use_selected_to_active=True, cage_extrusion=reach,
        max_ray_distance=reach * 2.0, margin=8, use_clear=clear, target="IMAGE_TEXTURES")
    if kind == "NORMAL":
        kwargs["normal_space"] = "TANGENT"
    if passes is not None:
        kwargs["pass_filter"] = passes
    bpy.ops.object.bake(**kwargs)


def bake_into(images, high, low, reach, first):
    """Bakes `high` onto `low`'s cell of the family's images: tangent-space
    normals, occlusion and colour. `first` clears the images."""
    _bake(high, low, "NORMAL", images["normal"], reach, first)
    _bake(high, low, "AO", images["ao"], reach, first, samples=48)
    _bake(high, low, "DIFFUSE", images["colour"], reach, first, passes={"COLOR"})


def pixels(image):
    data = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(image.size[1], image.size[0], 4)


def save_png(image, path, values=None):
    if values is not None:
        image.pixels.foreach_set(values.astype(np.float32).ravel())
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()


def _darken(images, occlusion):
    """The baked colour darkened by the baked occlusion (`occlusion` its share)."""
    shade = pixels(images["ao"])[..., :1]
    rgba = pixels(images["colour"])
    rgba[..., :3] *= (1.0 - occlusion) + occlusion * shade
    rgba[..., 3] = 1.0
    return rgba


def finish_atlas(images, colour_out, normal_out, occlusion=0.75):
    """The family's colour, darkened by its occlusion, to `colour_out`; its
    normals at half the size, renormalised, to `normal_out`."""
    save_png(images["colour"], colour_out, _darken(images, occlusion))
    normal = pixels(images["normal"])
    h, w = normal.shape[0] // 2, normal.shape[1] // 2
    half = normal[: h * 2, : w * 2].reshape(h, 2, w, 2, 4).mean(axis=(1, 3))
    vector = half[..., :3] * 2.0 - 1.0
    vector /= np.maximum(np.linalg.norm(vector, axis=2, keepdims=True), 1e-6)
    half[..., :3] = vector * 0.5 + 0.5
    half[..., 3] = 1.0
    small = bpy.data.images.new(images["normal"].name + "-half", w, h, alpha=False, float_buffer=False)
    small.colorspace_settings.name = "Non-Color"
    save_png(small, normal_out, half)


def bake_single(high, low, name, size, reach, colour_out, occlusion=0.75):
    """An impostor source's colour, darkened by its occlusion, baked onto its
    own UVs (`size` square) and saved to `colour_out`."""
    images = atlas(name, (size, size))
    _bake(high, low, "AO", images["ao"], reach, True, samples=48)
    _bake(high, low, "DIFFUSE", images["colour"], reach, True, passes={"COLOR"})
    save_png(images["colour"], colour_out, _darken(images, occlusion))


def plain(obj, label):
    """The exported mesh's one material, named for the game to paint; no
    picture is embedded."""
    material = bpy.data.materials.new(label)
    obj.data.materials.clear()
    obj.data.materials.append(material)


def footprint(obj):
    """The circle about the origin that holds the mesh at every turn, its top
    and its lowest point (Blender Z, metres)."""
    radius = max(math.hypot(v.co.x, v.co.y) for v in obj.data.vertices)
    top = max(v.co.z for v in obj.data.vertices)
    low = min(v.co.z for v in obj.data.vertices)
    return round(radius, 3), round(top, 3), round(low, 3)


def export_glb(obj, path):
    _activate(obj)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT")


def save_master(obj, kind, recipe):
    """Keeps only `obj` and saves it as the kind's master, its recipe's plain
    values as custom properties."""
    for other in list(bpy.data.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)
    for key, value in recipe.items():
        if isinstance(value, (int, float, str)):
            obj[key] = value
    bpy.context.preferences.filepaths.save_version = 0
    MASTERS.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTERS / (kind + ".blend")), compress=True, copy=True)


def rng(seed):
    return random.Random(seed)
