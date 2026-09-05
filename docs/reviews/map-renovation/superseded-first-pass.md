# Superseded visual experiment

Status: WIP checkpoint, explicitly superseded by the owner's instruction on
5 September 2026. This is not an approved design or a production candidate.

The owner rejected incremental polishing of the existing composition and
required a fresh assembly, with optional asset reuse. The floor texture was
promising as an image but too heavily repeated and blurred in the game.

This checkpoint preserves the experiment only: imported mesh atlases, a
route-derived terrain field, denser scenery, particles, a walked ribbon and
bounded GPU settling. Asset provenance and full delivery validation are not
complete. Do not merge this checkpoint or treat its images as design authority.

Focused evidence: the map scene and waylight tests passed before the final
visual adjustments. A new GPU-settling regression failed on the old behaviour
and passed after the bounded settling change. No complete final-candidate gate
or independent review has run.

Fresh assembly starts from the stable compiler, game-state and input contracts.
It must establish composition, physical scale, material scale, landscape and
landmark language before considering any of these visual implementations.
