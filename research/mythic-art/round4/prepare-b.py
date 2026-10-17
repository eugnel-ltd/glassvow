"""Prepare the six B compositions without touching the accepted A definitions."""
import ast
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent
values = {}
for node in ast.parse((ROOT/'prepare.py').read_text()).body:
    if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in ('KEY', 'GROUND', 'FRONT', 'LOOK'):
        values[node.targets[0].id] = eval(compile(ast.Expression(node.value), 'prepare.py', 'eval'), {'__builtins__': {}, 'dict': dict})
KEY, GROUND, FRONT, LOOK = (values[n] for n in ('KEY','GROUND','FRONT','LOOK'))
LOOK['knownRoad']['composition'] = '35 mm strict one-point night vista; vanishing point x61 percent y73 percent; distinctly LOW horizon; small door'
LOOK['unbowed']['composition'] = 'Knee-height 24 mm worm-eye wide view; upright back-facing figure at LEFT third; ash sweeps lower left towards upper right'
requests = {
 'bankedFire': [
  ('back', 'Empty distant slate-grey storm darkness, low macro side view. A broad grey ash ribbon crosses on a HARD DIAGONAL from upper left to lower right. The ribbon is stylised wind-blown powder rendered as two broad leaded glass bands, not a stream of stones. No pillar, stone, coal, figure, arch or building. Quiet dark blue-grey atmosphere behind a future huge close stone.', 'Opaque complete world, no key colour.'),
  ('ground', 'An empty ash-covered ground at very low macro eye level: broad soft grey powder deposits over cold slate glass. Gentle ash ripples, no paved slabs, bricks or grids. Entire lower half is uninterrupted ash support for a blunt stone and one small coal.', 'Lower 52 percent opaque unbroken ash ground extending to side and bottom edges. Upper 48 percent perfectly uniform RGB(255,0,255) magenta. Thick dark lead boundary, no shadow, coal, pillar, stone or other object.'),
  ('front', 'One low soft ridge of loose dark ash entering from the BOTTOM RIGHT, rising gently to the right edge, confined to lowest ten percent. One long dark silhouette, no pebbles or stone blocks.', FRONT),
  ('subject', 'ONE connected ancient stone arrangement only: a broad BLUNT NON-HUMAN weathered upright slab on the right, directly against the jagged SHATTERED BASE of a thicker pillar. The pillar is broken off at about two-thirds the slab height; its jagged broken top and three large fallen pieces are clearly visible AT THE SLAB BASE, not in the distance. The upright slab fills the right two-thirds of this object. The left third is an empty sheltered pocket at ground level for a separately added coal. No coal or warm light. Whole arrangement stands on one low baseline. No cradle, pedestal, face, head, shoulders, armour, inscription, symbols or writing. Large simple glass masses.', KEY),
  ('coal', 'ONE small squat coal banked under a thick soft skin of pale grey ash. Wide low oval silhouette, a SINGLE narrow AMBER fissure beneath the ash skin. Most of the coal is cold grey; no blazing flame, no flame tongue, no long radiant rays. A luminous ember held in reserve. Complete object, no hearth, stones, cradle, support or shadow. The coal is less than one-third the height of the future stone, but the amber point must survive at thumbnail size.', KEY)
 ],
 'silvering': [
  ('back', 'A quiet collapsed silver-glass mirror chamber seen slightly from above and over the left shoulder. A diagonal white shaft crosses a broad pale silver wall from upper right. Two large irregular silver-blue wall facets on the LEFT; right third mostly empty dark silver air and a quiet wall plane. No arch, mirror, person or red. Different room composition: wall corner left, open space right, no floor grid.', 'Opaque complete world plate, no key colour.'),
  ('ground', 'An uneven silver-grey rubble floor with a broad fallen leaded panel running diagonally away to the left, embedded fragments lying FLAT. Empty support for a freestanding mirror and walker boots. Elevated three-quarter view, quiet open floor on right. No objects standing up.', GROUND),
  ('front', 'One near silver-grey broken wall fin at the extreme upper LEFT and left edge, a thin dark blade of masonry confined to leftmost six percent; irregular heavy lead contour. Keep all central and lower-right space empty.', FRONT),
  ('mirror', 'ONE complete broad tall arched freestanding mirror viewed from above and slightly left. Broad pointed arch with a double silver came rim, heavy black outer lead. The arch opening is much wider than an ordinary narrow mirror, clear central glass. Two LOW wide integral buttress feet, not a pedestal. Empty unbroken dark silver-blue glass inside, no reflection, no person, no red, no ornament or symbol. Strong slightly oblique upright arch, entire object visible.', KEY),
  ('walker', 'ONE hooded walker viewed strictly FROM BEHIND, from above the left shoulder. Tall slim back silhouette, torn cloak hanging STILL, no face visible. Left hand holds a straight sword DOWN beside the left calf, point at boot level, right arm lowered. Head and feet upright. Complete two arms and two planted boots. Silver-blue leaded-glass armour, broad cold-white shoulder plane; no crimson. Whole object, no floor or other person.', KEY),
  ('double', 'ONE pale reflected hooded walker, front three-quarter turned towards the left. Faceless void hood with no eyes, two arms and legs. One sword already RAISED in the right hand, held across the upper chest pointing diagonally towards upper LEFT; other hand down. Exactly ONE THIN blood-moon crimson line down the cold silver blade, not a red sword. Silver-white simple long cloak silhouette, fully visible boots. No glow outside object.', KEY)
 ],
 'unbrokenFlame': [
  ('back', 'An empty small compressed black-claret reliquary niche, straight frontal view. Broad dark burgundy side wings angle slightly inwards around an empty rectangular black recess; no arch. Six-petal lantern will stand here later. Dark claret glass, heavy black came, very low contrast. No lantern, flame, rose, jewel, symbol, chain or blue.', 'Opaque complete background plate.'),
  ('ground', 'A broad altar top of nearly black claret glass, frontal telephoto view. One thick horizontal step, bevel at its front, dark matte face. Flat empty support for three short lantern feet, no object or glow.', 'Lower 25 percent opaque altar, top near y75 percent. Upper 75 percent perfectly uniform RGB(255,0,255) magenta. Surface extends beyond side and bottom edges, solid dark lead upper boundary. No violet or magenta on altar.'),
  ('front', 'Two small curved dark iron glass hooks emerging only at the two extreme bottom corners, symmetrical and low, no writing, symbol, flower or flame. Keep bottom centre open so lantern feet remain visible.', FRONT),
  ('subject', 'ONE tangible monumental squat lantern, frontal and completely symmetrical. Broad six-lobed ROSE body wider than A: exactly SIX large rounded petal panes around ONE WHITE-GOLD FLAME, no extra panes. Clockwise from top: FROST-WHITE, BLOOD-MOON CRIMSON, AMBER, FROST-WHITE, BLOOD-MOON CRIMSON, AMBER. Three colours each twice. The panes are broad and simple with very thick dark lead dividers and a bold six-lobed outline. The body stands on THREE short evenly spaced feet, not hanging, with one low pointed crown above. No separate circle around rose, no handle, chain, rays, secondary flame or small ornamental facets. Entire lantern visible with margin. Core is an actual flame, not a disc.', KEY)
 ],
 'unbowed': [
  ('back', 'Empty vast open wind-cut moor at dusk seen from knee height. Grey ash bands sweep on a HARD DIAGONAL from lower left to upper right. Broad neutral charcoal sky, distant dark heath low at y77 percent. Thin dull ember horizon only behind x35 percent. No figure, building, sword or sun. Strong large diagonal glass masses, no orange sky.', 'Opaque complete world plate.'),
  ('ground', 'A level dark ash-grey moor road seen from knee height. Broad quiet road surface, dead grass lying low at its right edge. Low flat horizon, road support is level even though the wind behind will tilt. No paving grid, stones, flame or figure.', 'Opaque unbroken ground in lower 24 percent, top near y76 percent; upper 76 percent perfectly uniform RGB(255,0,255) magenta. Reaches sides and bottom, black lead edge. No external shadow.'),
  ('front', 'One sparse near-camera fan of charcoal dead grass from BOTTOM RIGHT, long glass blades lean steeply UP RIGHT in the wind. Narrow edge-running occluder, keep lower centre and left clear, no rocks.', FRONT),
  ('subject', 'ONE full-length lone armoured walker seen from BEHIND and slightly from the right, camera at knee level looking up. Absolutely upright straight spine, head level, both boots planted level. Body completely still, a torn cloak hangs vertically with ragged strips, no billowing. Right hand holds a sword point straight DOWN at right side, tip at boot level. Two arms, two legs, no face or eyes. Broad smoked-grey glass shoulder armour and dark vertical cloak, very thin EMBER-ORANGE rim from directly behind. Rim only, no warm fill. No scenery or ground.', KEY)
 ],
 'knownRoad': [
  ('back', 'An empty night causeway landscape over still deep-blue water. Huge dark ultramarine sky fills upper 73 percent, low distant shoreline only at y73 percent. Quiet empty horizon at x61 percent. Broad leaded-glass sky planes angled towards that off-centre point, no stars, moon, building, door, road, footprints or warm light.', 'Opaque complete background.'),
  ('ground', 'One empty straight road of broad leaded DEEP-BLUE GLASS SLABS in strict ONE-POINT perspective. The road tip and vanishing point are EXACTLY x61 percent, y73 percent. Road expands from that tiny distant tip to both bottom corners, occupying only lower 27 percent. Slab joints converge precisely to that point. No door, arch, footprints, person, other path, shadow or gold. Quiet dark slabs, thick simple lead lines.', 'Only the triangular receding road is opaque; all space above and beside it perfectly uniform RGB(255,0,255) magenta. Road reaches both bottom corners and entire bottom edge. Heavy dark boundary.'),
  ('front', 'One low dark ultramarine causeway step bevel along bottommost five percent, its upper edge angles gently towards the right. No gold line. No rubble or many tiles. Keep the centre empty.', FRONT),
  ('subject', 'ONE SMALL plain arched doorway seen frontally. Heavy deep-blue glass frame, single broad stone-glass arch, low integral threshold, one CLOSED flat dark-blue door leaf filling the arch. Large clear plain leaf with no internal divisions. No handle, writing, ornament, extra wall or gold trim. Thick simple silhouette, whole object visible. This will be placed very small on a distant low horizon, NOT a towering portal.', KEY)
 ]
}
for card, items in requests.items():
    batch = [dict(LOOK[card], name=f'{card}-B-{layer}', request=req, surface=surface) for layer,req,surface in items]
    (ROOT/f'{card}-B-generation.json').write_text(json.dumps(batch,indent=2)+'\n')
# Clean Break B stays inside the new overhead relic look, with a different silhouette and cut direction.
a = json.loads((ROOT/'cleanBreak-redo-generation.json').read_text())
batch=[]
for spec in a:
    spec = dict(spec)
    spec['name'] = spec['name'].replace('cleanBreak-A-relic', 'cleanBreak-B-relic')
    layer=spec['name'].rsplit('-',1)[1]
    if layer=='back':
        spec['request']='Empty ancient steel-blue sanctuary floor seen almost straight OVERHEAD. Broad diagonal cold glass masonry runs from upper left towards bottom right. A quiet darker rectangular area fills the centre; no circle, octagon, object, sword, pane, arch or horizon. Monumental scale, matte dark steel-blue glass, thick black lead seams. No bright highlight.'
    elif layer=='ground':
        spec['request']='ONE massive empty rectangular cold sanctuary slab seen nearly straight down, its long sides angle slightly counterclockwise. Dark STEEL-BLUE stained glass, silver-cut bevel only at top edge, broad quiet central plane with no grid or ornament. No workbench, circle, object, weapon, pane or cut. Ancient ceremonial support extends past sides and bottom.'
    elif layer=='front':
        spec['request']='ONE broad dark silver-leaded sanctuary floor bevel enters only the BOTTOM RIGHT corner, with one small ice-cyan reflected edge. No sword, shard, rune or rubble. Keep the entire centre empty.'
        spec['composition']='Near-overhead view; only bottom-right six percent, edge-running through bottom and right edges'
    elif layer=='pane':
        spec['request']='ONE immense mythic relic: an elongated RECTANGULAR pane of FROST-WHITE glass with four CLIPPED CORNERS, laid flat and seen nearly overhead, turned 12 degrees counterclockwise. Its long edges carry a narrow magnificent SILVER CAME mount, broad cut-crystal bevels, restrained architectural tracery only on the perimeter. Broad uninterrupted frosted-white central field covering two-thirds of the face, no internal lines. Physical ancient relic with thickness, never a badge, logo, coin, rose or upright window. No cut yet; a SINGLE perfectly straight descending diagonal will be made later in composition. NO fracture, crack, splinter, chip, symbol, writing, runes, glyphs, sword or star. Complete object with ten percent margins. Bold heavy dark outer lead.'
    elif layer=='blade':
        spec['request']='ONE complete mythic LONGSWORD viewed nearly straight overhead. A broad double-edged frost-steel blade points diagonally UP LEFT, full dark blue wrapped GRIP and faceted crystal POMMEL at LOWER RIGHT, unmistakable silver swept CROSSGUARD between. The blade is broad, straight and simple, three large blue-white facets, heavy dark lead outline. Entire sword visible tip to pommel, no hand, floor, scabbard, fragments, glow, text, rune, inscription, emblem or gold. This sword has just left the lower-right end of a descending cut.'
        spec['composition']='Near-overhead 70 mm view; diagonal complete sword from upper-left tip to lower-right pommel, generous margins'
    batch.append(spec)
(ROOT/'cleanBreak-B-generation.json').write_text(json.dumps(batch,indent=2)+'\n')
print('Prepared six B batches: 28 calls; with five Clean Break A calls, 33 of 40 planned.')
