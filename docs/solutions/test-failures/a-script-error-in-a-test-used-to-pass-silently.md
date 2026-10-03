---
title: A script error inside a test used to pass silently; the runner now fails the test that raised it
date: 2026-10-03
category: test-failures
module: tests/run_all
problem_type: test_failure
component: testing_framework
severity: high
symptoms:
  - "SCRIPT ERROR: Invalid access to property or key 'mesh' on a base object of type 'null instance' on stderr, and the same test still printed ok"
  - "The suite printed PASS while a test's later checks had stopped running"
  - "test_map_open_cache's return-reuse checks (road geometry, ledges, another run's salt) had not run since R1 (#664) moved Act I to the journey land"
  - "A test that did not parse left the headless runner waiting forever after 'Invalid call. Nonexistent function 'run (via call)''"
  - "A script error raised by a test's deferred call was listed after PASS, and the run still exited 0"
root_cause: missing_tooling
resolution_type: tooling_addition
tags: ["test-runner", "script-error", "logger", "silent-pass", "godot-4.7"]
---

# A script error inside a test used to pass silently; the runner now fails the test that raised it

## Problem

`tests/run_all.gd` loads each `tests/test_*.gd` and calls its static
`run(fails)`. A test fails only by appending to `fails`, and the runner prints
`ok` when nothing was appended.

A GDScript runtime error does not append anything. It prints
`SCRIPT ERROR: ...` on stderr and aborts **only the function it is raised in**.
The caller carries on, `run` returns, nothing was appended, and the runner
printed `ok` and, at the end, `PASS`. Every check after the error never ran.

R1 (#664) made Act I draw the revived journey land, which has no painted road.
`test_map_open_cache`'s return check asked that land for its `Bridge masonry`
node, got `null`, and dereferenced it. From then on the road-geometry, ledge
and other-run checks never ran. The local gate and review both saw a green
suite, because the only sign was a `SCRIPT ERROR` among hundreds of lines of
harmless renderer noise on stderr.

## Root cause

The runner graded a test only by what the test chose to report. An error that
stops the test before it reaches its checks reports nothing, so it read as a
pass. Reading stderr would not have been a reliable fix. The headless dummy
renderer prints many plain `ERROR:` and `WARNING:` lines (null materials,
leaked RIDs, leaked instances at exit), and a script error printed among them
is easy to miss. Nothing in the process status told the two apart.

## Solution

Godot 4.5 added a `Logger` class. The engine hands every error it logs to each
logger registered with `OS.add_logger`, along with the error's type. The 4.7.2
signature, taken from the engine's own `--dump-extension-api`, is:

```gdscript
func _log_error(function: String, file: String, line: int, code: String,
		rationale: String, editor_notify: bool, error_type: int,
		script_backtraces: Array[ScriptBacktrace]) -> void
```

`tests/support/script_error_guard.gd` extends `Logger` and keeps only
`ERROR_TYPE_SCRIPT` errors: runtime errors, failed `assert`s and parse errors.
For a GDScript error, `file`, `line` and `function` are where it was raised and
`code` is the message. The runner registers the guard. After each test loads
and runs, the runner lets two frames run, then takes what was recorded since
the previous test. Each error becomes a failure of that test:

```text
FAIL res://tests/test_x.gd
FAIL (1)
  - res://tests/test_x.gd: script error at res://tests/test_x.gd:<line> in <function>(): <message>
```

The runner used to call every test inside its own `_initialize`, so no frame
ran until the last test had returned. Anything a test left behind (a deferred
call, a node's processing, a queued free, a timer or tween already due) raised
its error after the result was printed. Now the runner is a coroutine. After each test it
waits out two frames (`_settle`): the first finishes the frame the test returned
in, the second runs one whole frame more. Only then does it grade the test, so
such an error fails the test that left the work behind and not the next one.
A `run` that awaits is awaited too, so a check made after the await counts.

Frames also run before the first test. Every test therefore runs inside a
frame with the root window already sized, whether it runs alone or in the whole
suite. Before, every test ran ahead of the first frame, under a root window
that had not yet laid anything out. `test_map_compose`'s projection-cache check
relied on that by accident. It expected the first reader to find the cache
cold, but a screen that enters a sized root is laid out at once and has already
projected its pose. The check now reads first from a pose that nothing has
projected yet, and asserts exactly what it did before.

The root being in the tree also changed what adding a node under it does: the
engine now delivers `_ready` there and then. Suites written for the old runner
called `node._ready()` by hand after adding it, so those nodes were readied
twice. The reward embers connected `resized` twice, which showed only as nine
plain engine errors in the full gate. A suite now calls `TreeReady.once(node)`
(`tests/support/tree_ready.gd`), which runs `_ready` only when the engine has
not. Across the 13 suites that drive nodes by hand, 234 nodes were built
outside the tree and are readied once by hand, as before. The other nine had
already been readied by the engine.

What it deliberately does not do:

- **Plain engine errors and warnings fail nothing.** `ERROR_TYPE_ERROR`,
  `ERROR_TYPE_WARNING` and `ERROR_TYPE_SHADER` are ignored. This covers the
  headless renderer's null-material lines and the leak report at exit. It also
  covers `push_error`, which Godot logs as a plain engine error, not a script
  error. These lines stay on stderr, as before.
- **Script errors raised while the tree is torn down at exit fail nothing.**
  By then the result has been printed. Such an error comes from something a
  test left behind, but by then it cannot be pinned on one test. The
  runner's `_finalize` lists it under `run_all: script errors while the tree
  was torn down at exit, charged to no test (the result stands):`, still naming
  its file and line, and leaves the exit status alone.
- **A suite's in-tree half, run in a child Godot, is guarded too.** A suite
  that needs real frames runs `run_in_tree` in a child process through
  `tests/support/tree_suite.gd`, and the runner's logger does not reach that
  process. The child adds its own guard, settles two frames after the suite
  returns, and reports each script error as a failure line the runner reads
  back. Without it, a null access in `run_in_tree` passed: the coroutine
  ended early, the child still printed its done mark, and the suite printed
  `ok`.
- **A test that errors inside a loop does not flood the log.** The guard keeps
  the first five messages between two takes and counts the rest
  (`and N more script error(s)`).

What it cannot see:

- **Anything raised while `Engine.print_error_messages` is off.** The engine
  then hands no logger anything (`Logger::should_log`), so a script error in
  that window passes. The runner fails a test that leaves the setting off and
  turns it back on. A test that turns it off and back on is invisible, so do
  not silence the engine's error log in a test. The noise it would hide fails
  nothing anyway.
- **A call the engine refuses to make.** When a signal's handler takes the
  wrong arguments, the engine never runs the handler, but it logs that as a
  plain `ERROR: Error calling from signal ...`, not as a script error. Such a
  test passes unless its own checks notice that the handler did nothing.
- **When a worker's error was raised.** The engine may call `_log_error` from a
  worker thread (a worker-pool build reports its errors there), so the guard
  keeps its record behind a `Mutex`. It never prints from inside `_log_error`,
  because an error raised there would recurse. An error from a worker is
  charged to whatever the runner is doing when the worker logs it. If a test
  leaves a worker running after it returns, the error can fail the next test,
  or appear in the teardown list. If it is raised after `_finalize` has
  removed the guard (the engine joins its workers later, in its own cleanup),
  it appears only on stderr and the run passes. Whatever the guard records
  names the file and line where the error was raised. A test must join the
  workers it starts.

The guard showed up one more hole, and this one hung the runner instead of
passing. A test that fails to parse still loads as a `Script`, just an invalid
one. The same happens to a test whose `run` is missing, is not static, or
cannot take the runner's `Array[String]` (no parameter, two required ones, or a
parameter typed `Array[int]`). Calling `run` on such a script raises the call
error in the runner itself. That aborts the runner, so `quit` is never called
and the headless process waits forever. The runner now checks first that the
script parsed (`can_instantiate`). It also checks that the script declares a
static `run` that it can call with one `Array[String]`. Extra parameters with
defaults, and a variadic tail, are allowed. The first parameter must be untyped
or an `Array` or `Array[String]`. A script that fails either check is recorded
as `failed to load` or `has no static run(fails: Array[String])`, together with
its parse errors, and is never called.

`tests/test_script_error_guard.gd` holds the guard's filter, its message, its
bound and its count when eight workers log at once. `tests/test_run_all.gd`
holds the runner itself. It runs a copy of `run_all.gd` and the guard in a
headless child Godot, on a throwaway project whose tests are the fixtures in
`tests/support/run_all_fixtures/`. The run must fail each fixture that raises,
including through a deferred call, and must not charge that error to the next
fixture. It must count a check made after an await and fail a fixture that
leaves the error log off. It must refuse a `run` it cannot call, without
hanging, and call a `run` with a defaulted parameter. A selection of passing
fixtures, one of which calls `push_error`, must pass and exit 0. Unregistering
the guard, dropping its record or skipping the settle frames each fails this
test.

The printed format is unchanged: `ok   <path>` and `FAIL <path>` per test,
`PASS (N tests)` or `FAIL (N)` with `  - ` lines, and the same exit status.
CI and `tools/land_map_glb.py` read exactly those.

## Why this works

The question a runner must answer is "did every check in the test run and
hold?", not "did the test report a failure?". A script error is the commonest
way the engine says that a check did not run, and the `Logger` hands it to the
runner as data, with its type. Reading stderr would have meant matching text.
Because the guard sits in the runner, every existing and future test gets it
without any change to the test. A refused call is the other way, and it is
logged only as a plain error, so it stays the test's own job to notice (see
"What it cannot see").

## Prevention

- When a test looks up something that may legitimately be absent (a node by
  name, a dictionary key), read it with `get_node_or_null` or `get` and assert
  its presence through `_check`. The test then fails with a sentence that says
  what is missing, instead of a null access.
- When a presentation change moves an act to a different landscape (as R1 did
  for Act I), search `tests/` for the old landscape's node names. Move the
  checks to an act that still draws that landscape, and give the new landscape
  its own equivalent.
- Grade the suite by its exit status and its `PASS (N tests)` line. Stderr
  still carries harmless renderer noise. A script error now turns into a
  `FAIL` line, so you no longer need to look for it on stderr.
- To drive a node by hand, call `TreeReady.once(node)`, never `node._ready()`.
  The root is in the tree, so a node added under it has already been readied.
- Free a node whose method a worker may be running with `queue_free()` and a
  frame, as the game does, not with `free()`. A script `free()` is refused
  while the worker's call holds the node's lock, and the node leaks.
  `test_enemy_death_shards` did this, and the guard caught it as an
  intermittent `Attempted to free a locked object` in the full suite.
- Never turn `Engine.print_error_messages` off in a test, and join every worker
  a test starts before it returns. Both take an error out of the guard's view
  or out of its test.
