# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |
| —                         | `needs-local-machine` | Requires a local-only capability; cloud work can continue independently |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

A `needs-local-machine` issue names the exact candidate head, local procedure, required capability and expected evidence. It may also be `ready-for-agent`: the agent on the local machine can perform the step. It does not automatically require human implementation. Device QA, NAS, local image generation, signing/store uploads and self-hosted runner administration use this label; see `docs/agents/cloud-environment.md`. Initial examples are #742 and #749.
