class_name ActFlag
extends RefCounted
## The `--act=N` command-line convention, and the one place it is translated.
##
## `--act=` takes an act NUMBER, counted from 1 the way everyone says it:
## `--act=1` is Act I and `--act=4` is Act IV. Everything inside the game counts
## from 0 and calls the result an act INDEX: `RunState.act`, the `LayoutBook` and
## `MapRegions` tables, `MapLandscapeAssets`, and the `act` field of
## `assets/art/map/map-assets.json` (where `-1` marks the kits every act shares).
##
## `parse` is the only function that turns the first into the second, so the
## off-by-one that once made `--act=1` render Act II (#451) has one place to live
## and one test. Nothing is clamped: a value that is out of range or unreadable is
## refused with a message that states the convention, because the silent
## alternative is a plausible frame of the wrong act.

const PREFIX: String = "--act="
const USAGE: String = "--act= takes an act number counted from 1 " \
	+ "(--act=1 is Act I) up to %d; got '%s'"


## `{"act_index": int}` for a valid act number, otherwise `{"error": String}`
## holding the message to print.
##
## A value is valid exactly when it is the plain decimal of an act number, so an
## empty value, garbage, a fraction, a sign, padding, leading zeros and anything
## outside 1..`LayoutBook.ACTS` are all refused. It is matched against `number_of`
## rather than parsed, which keeps `parse` the inverse of `number_of` by
## construction and never asks the engine to read a number it cannot hold.
static func parse(value: String) -> Dictionary:
	for act_index: int in LayoutBook.ACTS:
		if value == str(number_of(act_index)):
			return {"act_index": act_index}
	return {"error": USAGE % [LayoutBook.ACTS, value]}


## The act number a person reads for an act index, for the labels and messages
## that name an act.
static func number_of(act_index: int) -> int:
	return act_index + 1
