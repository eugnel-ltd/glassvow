Device batch 2 (iPad 8, A12), #657 PR 3 after the review round. Head tested:
see the head line in batch.log.txt. summary.txt is `python3 summary.py b2`
over the per-run rows (the raw rows, about 1 MB, are not kept). Columns:
build = the fight's load frame; N+1, N+2 = the next two frames; ent10 = worst
of the next ten; pic1/liv1 = first picture and live turns' worst frames and
their pipeline compiles (c); bake = the bake at the turn when there is no
pre-warm. Runs named C or F are cold (shader cache wiped), H are warm. The
device UDID is redacted in the scripts.
