class_name NextActMap
extends RefCounted
## The map the next act will open on, worked out ahead on a copy of the run
## (#660 II.3): the journey prefetch builds Act II's land under Act I's boss
## rewards, before the run reaches that map.
##
## Once an act's boss is beaten, nothing the player still does before the next
## act's map draws on the run's randomness except the crown's offer: picking a
## card or a relic draws nothing. So the same steps `Main` takes on a copy
## (`_show_boss_relic`'s offer when it is not rolled yet, `_on_boss_relic_chosen`'s
## next act, its map and its quests' marks) give the map the run will open on.
## The run itself is never touched. A prediction the run then leaves (a
## reward that draws after all) only builds a land nothing opens: the
## prefetch keys on the map, and the screen builds its own.


## A copy of `run` standing at the start of the next act, its map drawn, or
## null: the act's boss is not yet beaten on `map`, the run ends with this act,
## or the run does not copy.
static func predict(run: RunState, map: WorldMap, content: ContentDB) -> RunState:
	var node: MapNode = map.current()
	if node == null or node.type != "boss" or not map.is_cleared(map.at) or run.is_final_act():
		return null
	var copy: RunState = RunState.from_save_dict(run.to_save_dict(), content)
	if copy == null:
		return null
	var game: GlassvowGame = GlassvowGame.new(content, copy)
	if not copy.quest_scratch.has("bossRelicOffer"):
		game.rewards.roll_boss_relics(copy)
	copy.start_next_act(content)
	var next: WorldMap = WorldMap.for_run(copy, content)
	game.quests.decorate_map(copy, next)
	copy.map = next.to_dict()
	return copy
