class_name FlameLines
extends RefCounted
## The lantern's lines (docs/design/2026-09-29-dusk-flame §10). Two consecutive
## flame readings name the line-table slots they owe; the existing once gates
## (`PoolBeats.draw` over the Vigil's `line_once` and the run's own draws, and
## `scenes_seen` once a line has played as a run scene) decide which are still
## unheard, so each line is heard once per Vigil. Pure: nothing here is saved.
##
## First Steady is the Lamplighter's line, carried by a whisper when he is not
## met at that reading. No reading can fall inside a meeting: the flame is read
## at combat start and after commands, and none of his five prices touches the
## deck. So the whisper carries it.

const SLOT_STEADY: String = "flame.steady"
const SLOT_FRINGE: String = "flame.fringe"
const SLOT_TRUE: String = "flame.true"
const SLOT_SOOT: String = "flame.soot"
## The whispers a reading can owe, in the order they play.
const SPOKEN: Array[String] = [SLOT_STEADY, SLOT_FRINGE, SLOT_TRUE, SLOT_SOOT]
## The Vigil's whisper for a walker who fell in Soot: that fall's epitaph.
const SLOT_SOOT_DEATH: String = "flame.sootDeath"
## One codex sentence per colour, `codex.lantern.<way id>`, revealed once that
## colour has been seen steady (a true flame is steadier still).
const CODEX_PREFIX: String = "codex.lantern."
## The flame before a run's first reading: the starter deck's (§4, "Start").
## A resumed run starts from it too; the once gates keep that from repeating
## a line already heard.
const START: Dictionary = {"tier": Flame.TIER_KINDLING, "fringe": ""}


## The slots the reading `after` owes, in the order they play: the whisper of a
## tier the flame has just entered (a change of tier since `before`), then the
## codex sentence of a colour that reads steady. A fringe that appears without
## a change of tier is no transition and owes no whisper.
static func owed(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var tier: String = str(after.get("tier", ""))
	if tier != str(before.get("tier", "")):
		if tier == Flame.TIER_STEADY:
			out.append(SLOT_STEADY)
			if not str(after.get("fringe", "")).is_empty():
				out.append(SLOT_FRINGE)
		elif tier == Flame.TIER_TRUE:
			out.append(SLOT_TRUE)
		elif tier == Flame.TIER_SOOT:
			out.append(SLOT_SOOT)
	var colour: String = codex_slot_of(after)
	if not colour.is_empty():
		out.append(colour)
	return out


## The codex slot of a reading whose colour is steady; empty otherwise.
static func codex_slot_of(reading: Dictionary) -> String:
	var tier: String = str(reading.get("tier", ""))
	var dominant: String = str(reading.get("dominant", ""))
	if dominant.is_empty() or (tier != Flame.TIER_STEADY and tier != Flame.TIER_TRUE):
		return ""
	return CODEX_PREFIX + dominant


static func is_codex(slot: String) -> bool:
	return slot.begins_with(CODEX_PREFIX)


## The epitaph slot a fall owes before the loss pool: Soot's, when the walker
## fell with the flame in Soot. Empty otherwise.
static func death_slot(reading: Dictionary) -> String:
	return SLOT_SOOT_DEATH if str(reading.get("tier", "")) == Flame.TIER_SOOT else ""


## The codex sentences revealed so far, in table order: each colour seen steady
## once in this Vigil, whether folded into `line_once` or drawn by `run`, the
## run still under way (null when there is none).
static func codex(content: ContentDB, vigil: VigilState, run: RunState) -> Array[Dictionary]:
	var heard: Dictionary = {}
	for id: String in vigil.line_once:
		heard[id] = true
	if run != null:
		for id: String in run.pool_draws:
			heard[id] = true
	var out: Array[Dictionary] = []
	for row_v: Variant in content.line_table:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		if is_codex(str(row.get("slot", ""))) and heard.has(str(row.get("id", ""))):
			out.append(row)
	return out
