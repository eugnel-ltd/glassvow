# Issue #461 scenery-compiler review

This packet repeats the exact #529 production matrix for the locked scenery
placement slice. It is owner-eye evidence for the working-tree candidate. It
does not claim commercial-grade approval and does not close #461.

## Provenance

| Item | Value |
| --- | --- |
| Before packet | `docs/reviews/529/` at `main@c28ae388` |
| Candidate | Working tree based on `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Candidate tracked-diff SHA-256 | `9de47eef17c91b1b30991762e8c867fb074e243c1d66c41dd513654cbc8d642a` |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| Renderer | macOS Metal, Compatibility |
| Matrix | The same 5 compiler inputs and 12 frames as #529 |
| Process result | Exit 0; 12 of 12 frames |
| Capture command | `tools/capture_build4_map_corpus.sh --output docs/reviews/461-scenery` |
| Observed runtime | 853.06 seconds |
| Compiler wall-clock | 846.501 seconds across the five inputs |
| Asset manifest SHA-256 | `bd9f8566c8395113fd01a4be8a5b56ccf92e14218e83012ba547828c966dc0fd` |
| Capture manifest SHA-256 | `bc0ba866a4fec61c3453ec3d3d82b0fa15330dd3517177560622e85d1f717e0c` |

The 12 frame keys and all five compiler input digests are byte-equal to #529.
The layout digests change because `scenery_instances` now participates in
layout identity, as intended by the slice:

| Act | Seed | #529 layout | Candidate layout | Scenery |
| --- | ---: | --- | --- | ---: |
| I | 17634 | `01a3f9fd…` | `5a7d6a43…` | 15 |
| I | 717 | `d61f52a1…` | `9b182e7c…` | 21 |
| II | 717 | `6baecd11…` | `6d5bd64…` | 19 |
| III | 717 | `dd8b436d…` | `54341c63…` | 18 |
| IV | 717 | `db60e0d0…` | `a9951414…` | 17 |

## Implementer inspection

The selected frames were inspected at original packet resolution. Compared
with #529, Acts I–III now show materially more scenery in free space across
both pad and phone shapes, while the captured routes and waystone silhouettes
remain visibly readable. The Act IV control remains furnished at 17 compiled
instances. These are implementation observations, not an owner verdict.

The four composition soft scores, new art, ground or terrain work, and changes
to routes, waylights or the camera remain follow-ups outside this slice.

## Before and after

### Act I - seed 17634

| #529 before | Scenery-compiler candidate |
| --- | --- |
| ![Act I seed 17634 before](../529/act-01-seed-17634-after.jpg) | ![Act I seed 17634 after](act-01-seed-17634-after.jpg) |

Candidate contact-sheet SHA-256:
`a49f137f8f27b8c40580da140a9ee5c0a7ed8d2d7ce8b35db1baad1a480ad5c3`

### Act I - seed 717 and travel midpoint

| #529 before | Scenery-compiler candidate |
| --- | --- |
| ![Act I seed 717 before](../529/act-01-seed-717-after.jpg) | ![Act I seed 717 after](act-01-seed-717-after.jpg) |

Candidate contact-sheet SHA-256:
`28a7f08743f7cfdff16143cba13d99888f495ff5958ef5358c6b00ce5e27f7a0`

### Acts II-IV - seed 717

| #529 before | Scenery-compiler candidate |
| --- | --- |
| ![Acts II-IV before](../529/acts-02-04-seed-717-after.jpg) | ![Acts II-IV after](acts-02-04-seed-717-after.jpg) |

Candidate contact-sheet SHA-256:
`72c0a16efcadbc1999d36a38e98f95e9a8a50b54852fa1da66d1bfa4b41c386c`

The manifest preserves the complete frame identity, current layout digests,
scenery counts and per-input compiler wall-clock. No port-owned golden changed.
