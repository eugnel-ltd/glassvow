RoomWarm pacing (#655, before TestFlight build 20), 4 Oct 2026. iPad 8 (A12, 3 GB), QA app
io.fol2.glassvow.qa only, the shared batch lock held per batch, every row echoing its launch's nonce.

before-attribution-ipad8.txt   main at 1b00ac3c, d402820b (#669) and 2d2c462d (#670): the title's
                               frames for 360 frames after the rite lands, video memory at the landing,
                               6 s later and after the warms, and RoomWarm instrumented per step (each
                               room's build, each shaping frame, each glyph set drawn in _draw).
                               Arms: main, nomap (no map warm), noroom (no RoomWarm), bare (neither).
before-plan.txt                its launch order (A, C and B interleaved, rested 12 s).
after-ipad8.txt                the fix e97b4dba on main be96dc83: RoomWarm on (main) and off (noroom),
                               the map warm on in both, en and zh-Hant, 720 frames after the landing.
after-plan.txt                 its launch order.
first-openings.txt             the rooms bench on e97b4dba: each room's first opening after the warm,
                               apart from laps 2-10, the first launch after the install and the next four.
qa_attr_patch.py.txt,          the QA-only patches (never committed to the game): the probe's hooks in
qa_attr_patch_fix.py.txt       Main, the prefetch and RoomWarm, for the old and the new RoomWarm.
qa_title_attr.gd.txt,          the probe and its marks.
qa_marks.gd.txt
attr_summary.py.txt            the summary script that wrote before- and after-ipad8.txt.
batch.sh.txt                   the batch: installs, nonce checks, lock, the copy-hang guard.
reports/                       each bench launch's on-screen report, read off a screenshot: the device's
                               file service hung (copies from the QA container timed out from 10:05),
                               so a QA-only patch drew the bench's summary over the screen once it
                               was done; each report names its build and its launch's nonce.
qa_rooms_patch.py.txt,         the bench's QA patch (PR B's), the on-screen report added to it, and
qa_rooms_patch_report.py.txt,  the batch that installed it and read each report off the screen.
qa_report_tail.gd.txt,
report_batch.sh.txt

The cause: TextServer re-sends a font page's whole image to the GPU when a newly rasterised glyph has
dirtied it (Godot 4.7 modules/text_server_adv, _font_draw_glyph), so drawing every glyph in one frame
re-uploaded pages hundreds of times in that frame and grew the RenderingDevice upload staging buffer,
which does not shrink.
