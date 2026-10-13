# R3.4: the water (issue #660)

## Pre-registered before the device batch (14 Oct 2026, 00:40 BST)

The batch is one interleaved batch on the iPad 8, QA app only: main
`97890cad` against the branch's code-final head `74c2c62c`, two installs
each, in the order main, branch, main, branch.

- **Rest.** Every view (Journey, the river, Close, Whole act), at the cadence
  and live, every launch: no missed frame (25 ms), and no visible hitch.
- **Video memory.** The water adds no texture and no sampler. Its own delta,
  paired against main within the same boot mode (each Journey hold classed
  high or low by its build's own cluster), is budgeted at **+2 MiB**. Over
  that, or on any memory warning or kill, the staging uploads are
  investigated (the orchestrator's ruling of 14 Oct); otherwise they are not.
- **Memory.** The app's peak physical footprint in each boot launch (an
  Activity Monitor recording across it) and every memory warning the OS
  sends (a probe row) are recorded, for both builds.
