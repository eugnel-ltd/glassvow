# Gravewarden round 3, second cap trial: dark inner lining on each rigid piece.
# The first trial spans concave rims with long fans across neighbouring pieces. This repair
# reverses an exact copy of each surface triangle. Back-face culling keeps its exterior
# unchanged and exposes dark stone on the inside. No cap spans another piece region.
# Every added vertex inherits exactly one bone. No motion or original surface is changed.
# Run with Blender --background --factory-startup --python-exit-code 1 --python <this file> --.
from pathlib import Path
# Reuse the first trial texture, topology and resource checks without executing its build.
original = Path(__file__).with_name("gravewarden_round3_cap.py")
exec(compile(original.read_text().rsplit("\nmain()", 1)[0], str(original), "exec"))
out = folder / "rig-round3-capped2"
THICKNESS = 0.0

def main2():
    resources()
    assert sha(folder / "rig-contact-batch" / "gravewarden.glb") == BASELINE_SHA
    assert not out.exists(), "Preserve the existing trial"
    blend_sha = sha(source)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
    me = body.data
    fps = bpy.context.scene.render.fps
    f0, l0 = len(me.polygons), len(me.loops)
    old_co = np.array([me.vertices[l.vertex_index].co[:] for l in me.loops])
    old_uv = np.array([x.uv[:] for x in me.uv_layers.active.data])
    old_norm = np.array([x.vector[:] for x in me.corner_normals])
    box, swatch = dark_block(base_image(me.materials[0]))
    bm = bmesh.new(); bm.from_mesh(me)
    dl, uvl = bm.verts.layers.deform.active, bm.loops.layers.uv.active
    groups = {}
    for v in bm.verts:
        assert len(v[dl]) == 1 and abs(next(iter(v[dl].values())) - 1) < 1e-6
        groups.setdefault(next(iter(v[dl].keys())), []).append(v)
    for vs in groups.values():
        bmesh.ops.remove_doubles(bm, verts=vs, dist=1e-6)
    bm.normal_update()
    outer = list(bm.faces)
    rim = [e for e in bm.edges if e.is_boundary]
    inner = {}
    for v in list(bm.verts):
        w = bm.verts.new(v.co)
        w[dl][next(iter(v[dl].keys()))] = 1.0
        inner[v] = w
    added = [bm.faces.new([inner[v] for v in reversed(f.verts)]) for f in outer]
    u0, v0, du, dv = box
    for f in added:
        f.smooth = False; f.material_index = 0
        for l, uv in zip(f.loops, [(u0,v0),(u0+du,v0),(u0+du/2,v0+dv)]):
            l[uvl].uv = uv
    bm.normal_update(); bm.to_mesh(me); bm.free(); me.update()
    assert np.array_equal(old_co,np.array([me.vertices[l.vertex_index].co[:] for l in me.loops[:l0]]))
    assert np.array_equal(old_uv,np.array([x.uv[:] for x in me.uv_layers.active.data[:l0]]))
    normal = np.empty((len(me.loops),3)); normal[:l0] = old_norm
    for f in me.polygons[f0:]:
        normal[f.loop_start:f.loop_start+f.loop_total] = f.normal
    me.normals_split_custom_set(normal.tolist())
    me.calc_loop_triangles()
    co = np.array([v.co[:] for v in me.vertices])
    tri = np.array([t.vertices[:] for t in me.loop_triangles])
    vbone = np.array([body.vertex_groups[v.groups[0].group].name for v in me.vertices])
    rows = pieces(co,tri,vbone)
    assert len(added) == f0
    assert all(len(v.groups) == 1 and v.groups[0].weight == 1 for v in me.vertices)
    report = {"source_blend":str(source), "source_blend_sha256":blend_sha,
              "baseline_glb_sha256":BASELINE_SHA, "method":"exact reversed dark inner lining; one-sided material; no new spatial extent",
              "fps":fps, "cap_texels":swatch, "thickness_m":THICKNESS,
              "rim_edges":len(rim), "pieces":rows,
              "vertices_after":len(me.vertices), "triangles_after":len(tri),
              "cap_triangles":len(tri)-f0, "source_corner_position_max_delta":0,
              "source_corner_uv_max_delta":0}
    resources()
    assert bpy.context.scene.render.fps == fps
    out.mkdir()
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "gravewarden.blend"))
    bpy.ops.export_scene.gltf(filepath=str(out / "gravewarden.glb"), export_format="GLB",
                             export_animations=True, export_animation_mode="ACTIONS")
    assert sha(source) == blend_sha
    assert sha(folder / "rig-contact-batch" / "gravewarden.glb") == BASELINE_SHA
    report["glb_sha256"] = sha(out / "gravewarden.glb")
    (pipeline / "gravewarden_round3_cap2.json").write_text(json.dumps(report,indent=2)+"\n")
    print("CAP2 DONE",json.dumps(report),flush=True)

main2()
