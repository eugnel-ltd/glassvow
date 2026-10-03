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
`code` is the message. The runner registers the guard, and after each test
loads and runs it takes what was recorded since the previous test. Each error
becomes a failure of that test:

```text
FAIL res://tests/test_x.gd
FAIL (1)
  - res://tests/test_x.gd: script error at res://tests/test_x.gd:<line> in <function>(): <message>
```

What it deliberately does not do:

- **Plain engine errors and warnings fail nothing.** `ERROR_TYPE_ERROR`,
  `ERROR_TYPE_WARNING` and `ERROR_TYPE_SHADER` are ignored. This covers the
  headless renderer's null-material lines and the leak report at exit. It also
  covers `push_error`, which Godot logs as a plain engine error, not a script
  error. These lines stay on stderr, as before.
- **Script errors after the last test fail nothing.** A deferred call, the last
  frame, or the tree's teardown can raise one after the runner has printed its
  result, and they belong to no test. The runner's `_finalize` prints them
  under `run_all: script errors after the last test, attributed to no test (the
  result stands):` and leaves the exit status alone.
- **A test that errors inside a loop does not flood the log.** The guard keeps
  the first five messages between two takes and counts the rest
  (`and N more script error(s)`).

The engine may call `_log_error` from a worker thread (a worker-pool build
reports its errors there), so the guard keeps its record behind a `Mutex`.
It never prints from inside `_log_error`, because an error raised there would
recurse. An error raised on a worker is charged to the test that is running
when it is logged. A worker started by one test that errors during the next
would be charged to the next one. Either way, the failure names the file and
line where the error was raised, so it can still be traced.
`tests/test_script_error_guard.gd` holds the guard's filter, its message, its
bound and its count when eight workers log at once.

The guard showed up one more hole, and this one hung the runner instead of
passing. A test that fails to parse still loads as a `Script`, just an invalid
one. The same happens to a test whose `run` is missing, takes no argument or is
not static. Calling `run` on such a script raises the call error in the
runner's own `_initialize`. That aborts the runner, so `quit` is never called
and the headless process waits forever. The runner now checks first that the
script parsed (`can_instantiate`) and that it declares a static `run` taking one
argument. A script that fails either check is recorded as `failed to load` or
`has no static run(fails)`, together with its parse errors, and is never called.

The printed format is unchanged: `ok   <path>` and `FAIL <path>` per test,
`PASS (N tests)` or `FAIL (N)` with `  - ` lines, and the same exit status.
CI and `tools/land_map_glb.py` read exactly those.

## Why this works

The question a runner must answer is "did every check in the test run and
hold?", not "did the test report a failure?". A script error is the engine
saying that a check did not run, and the `Logger` hands that to the runner as
data, with its type. Reading stderr would have meant matching text. Because
the guard sits in the runner, every existing and future test gets it without
any change to the test.

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
