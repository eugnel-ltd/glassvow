# R3.5: the set pieces (issue #660)

## Pre-registered before the device batch (14 Oct 2026, 04:45 BST)

The batch is one interleaved batch on the iPad 8, QA app only: main
`774c5932` against the branch's code-final head `4a95dbd5`, two installs
each, in the order main, branch, main, branch.

- **Rest.** Every view (Journey, the river, Close, Whole act), at the cadence
  and live, every launch: no missed frame (25 ms) that the branch has and
  main does not, and no visible hitch.
- **Video memory.** The new pieces add no texture and no sampler: one small
  mesh (the pier, 304 triangles, drawn as one more batched kind), more banner
  instances and a parapet mesh about 1.2 times main's. Their delta, paired
  against main within the same boot mode (each Journey hold classed by its
  build's own cluster), is budgeted at **+2 MiB**. Over that, or on any
  memory warning or kill, the uploads are investigated; otherwise not.
- **Memory.** The app's peak physical footprint in each boot launch (an
  Activity Monitor recording) and every memory warning the OS sends (a probe
  row) are recorded, for both builds.
