# Remember departure defaults without restoring run authority

The nonvisual persistence follow-up under [#661](https://github.com/eugnel-ltd/glassvow/issues/661#issuecomment-6248556687)
adds the cross-launch behaviour left outside the earlier opening lane's scope in
`docs/design/2026-10-02-opening-start/README.md` §17.5. It depends on the atomic
settings writer at `0386922fb79948fb7cc0c98682825001f1f82ba9` and does not change
the v2 run or Vigil envelopes.

`Preferences` stores one additive `[departure]` / `setup` value containing only
the stable aspect ID, vow level and art ID. For example:

```json
{"aspect": "duskblade", "vow": 1, "art": "beacon"}
```

No seed, run ID, boon, reveal or unlock is stored. Malformed optional values are
ignored without rewriting the file. The atomic writer retains unrelated settings
and the previous accepted file if writing fails.

Main resolves the IDs against the current catalogue each time it builds Embark.
The current `ClassScope.admits`, Vigil vow entitlement and `RewardRules.offer_arts`
remain authoritative. Unknown, deferred, locked or excluded choices hide the
shortcut rather than quietly turning into different defaults. Without the
Lamplighter, only the class's normal art qualifies.

Choosing the shortcut still enters the normal new-run path and keeps the gift a
real choice. The existing fresh-seed allocation remains in `_new_run`; looking up
defaults neither constructs another new run nor advances its random cursor.

A new departure owes remembered defaults after its run checkpoint succeeds and
its gift, if any, is complete. Failed checkpoints retain that debt for Retry.
A saved gift can finish in a fresh Main instance; its successful checkpoint also
records the accepted setup. The installed run and Vigil profile, together with
the existing story-flow gate, controls whether a departure can be remembered.
Onboarding captures deliberately keep story flow active but use the Development
profile, so they leave the player's preference bytes untouched. The existing
`select_profile` rule also isolates new tooling flags automatically. An explicit
`--production-save` opt-out retains player-profile authority; installing a
Development profile later still excludes it. Suppressed and Scenario starts
remain excluded by the story-flow gate.
The default Preferences stand-in does not publish defaults from throwaway Main
instances; those keep their own session memory.

Run acceptance and preference persistence are distinct: a successful checkpoint
does not become a failed run because the optional settings write fails. The last
durable preference may remain older in that case. These files are not one atomic
transaction, and the remembered value never supplies progress or load authority.

`tests/test_departure_persistence.gd` covers disk reload into a fresh Main, the gift,
fresh-seed authority, malformed values, current entitlements and checkpoint Retry.
`tests/test_departure_persistence_resume.gd` covers a pending gift loaded from a
checkpoint into another Main. `tests/test_departure_memory_profile.gd` protects
accepted preference bytes from onboarding and other Development starts, including
a resumed gift, while preserving the explicit production-profile opt-out.
Existing departure, class-scope, preferences,
atomic-write and profile-isolation suites remain complementary regression gates.
