class_name PoolBeats
extends RefCounted
## Run-scoped LineTable staging. Select once per beat key; presentation only
## resolves the stored id. Replay of the same key must not roll again.

const SLOT_WAYSTONE: String = "waystone"
const SLOT_HEARTH: String = "hearth"
const KEY_START: String = "hearth:start"
const KEY_USURPER: String = "hearth:usurper"
const RESUME_MAP: String = "map"
const RESUME_NODE: String = "node"
const RESUME_LEAVE: String = "leave"
const RESUMES: Array[String] = [RESUME_MAP, RESUME_NODE, RESUME_LEAVE]
## The L2 closers (04-delivery): a journey's closing row, played once straight
## after the fight that completes it. The act-2 boss win can close two
## journeys at once; they play in `BOSS_CLOSERS` order, one after the other.
## A drawn closer plays as a run scene, not a pending pool line: it follows a
## win whose reward or run end is already pending, which a pool line may not.
const CLOSERS: Dictionary[String, String] = {
	"ownShade": "closer.ownShade",
	"usurper": "closer.usurper",
	"eighthOmen": "closer.eighthOmen",
}
const BOSS_CLOSERS: Array[String] = ["usurper", "eighthOmen"]
## The Queue's L3 row, heard once after the first Act IV crossing.
const SLOT_L3: String = "closer.l3"
const KEY_L3: String = "closer:l3"

static func waystone_key(node_id: Variant) -> String:
	return "waystone:%s" % str(node_id)


static func pending_of(run: RunState) -> Dictionary:
	if typeof(run.pending_pool) != TYPE_DICTIONARY:
		return {}
	return run.pending_pool


static func row_of(rows: Array, run: RunState) -> Dictionary:
	var pending: Dictionary = pending_of(run)
	if pending.is_empty():
		return {}
	return LineTable.row_by_id(rows, str(pending.get("id", "")))


static func context_of(run: RunState) -> Dictionary:
	return LineTable.context(run, LineTable.projected_shard_count(run))


static func memory(vigil: VigilState, run: RunState) -> Dictionary:
	var once: Array = vigil.line_once.duplicate()
	for id: String in run.pool_draws:
		if not once.has(id):
			once.append(id)
	var last_id: String = ""
	if not run.pool_draws.is_empty():
		last_id = run.pool_draws[run.pool_draws.size() - 1]
	return {
		"recent": vigil.line_recent,
		"once": once,
		"last_id": last_id,
	}


## Empty dict = no matching row. A prior draw for `key` is replayed without
## consuming RNG.
static func stage(
		run: RunState, vigil: VigilState, content: ContentDB,
		slot: String, key: String, resume: String
) -> Dictionary:
	if resume not in RESUMES:
		return {}
	var row: Dictionary = draw(run, vigil, content, slot, key)
	if not row.is_empty():
		run.pending_pool = _pending(slot, str(row.get("id", "")), key, resume)
	return row


## Select once per `key` and record the draw, without staging it: the caller
## decides how the row plays. A prior draw is replayed without consuming RNG.
static func draw(
		run: RunState, vigil: VigilState, content: ContentDB, slot: String, key: String
) -> Dictionary:
	if key.is_empty() or slot.is_empty():
		return {}
	if run.pool_beats.has(key):
		return LineTable.row_by_id(content.line_table, str(run.pool_beats[key]))
	var row: Dictionary = LineTable.select(
		content.line_table, slot, context_of(run), run.rng, memory(vigil, run))
	var id: String = str(row.get("id", ""))
	if id.is_empty():
		return {}
	run.pool_beats[key] = id
	run.pool_draws.append(id)
	return row


static func closer_key(quest_id: String) -> String:
	return "closer:%s" % quest_id


## The boss-win closers still to try once `quest_id`'s has played.
static func closers_after(quest_id: String) -> Array[String]:
	var out: Array[String] = []
	var at: int = BOSS_CLOSERS.find(quest_id)
	if at >= 0:
		out.assign(BOSS_CLOSERS.slice(at + 1))
	return out


static func clear_pending(run: RunState) -> void:
	run.pending_pool = null


static func _pending(slot: String, id: String, key: String, resume: String) -> Dictionary:
	return {"slot": slot, "id": id, "key": key, "resume": resume}
