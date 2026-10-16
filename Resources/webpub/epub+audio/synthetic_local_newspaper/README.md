# Synthetic local newspaper fixture

A compact, copyright-clear WebPub reproducing the navigation shapes of Nota local newspapers. All text and audio are synthetic. The original 19-file shape has been reduced to three files, six cues, and 60 seconds of tones. Each cue lasts ten seconds to leave room for slow simulator startup and delayed events; tests can seek directly to every boundary. The retained resource and element names keep existing regression references recognizable.

## Cases

| Target or cue | Expected behavior |
| --- | --- |
| `np-0001.xhtml#prelude`, t=0–10 | No ToC owner: the cue precedes every anchored entry and there is no file-only entry |
| `np-0001.xhtml#e2` (empty heading) | Seek forward to `#e4` at t=10, although it has no narrated descendant |
| `np-0001.xhtml#e3` (section) | Seek to its first narrated descendant, `#e4` at t=10 |
| `np-0001.xhtml#e4`, t=10–20 | The deeper heading owns this cue, even though the section shares its first cue |
| `np-0011.xhtml#e166` (section), t=0–10 | Seek to `#e168`; its owner is `#e166` |
| `np-0011.xhtml#e198` (aside), t=10–30 | Seek to `#e199`; it and the following `#e200` keep owner `#e198` |
| Next from `np-0011.xhtml#e198` | Cross the resource boundary to `np-0012.xhtml#e202`, cue `#e204` at t=0 |
| Missing anchor in the playing file | Preserve playback; do not fall back to the file's first cue |

The narration contains a file-level wrapper followed by cues, with no section or aside containers. Those ToC entries therefore require XHTML lookup. The ToC has six entries, depth three. First-section seeking must be identical before and after asynchronous owner enrichment.

The audio uses 440/660/880 Hz tones generated with FFmpeg's `sine` source, concatenated in ten-second clips, mono 22.05 kHz MP3 at 32 kbps. No voice, copyrighted recording, or external service is needed. The tests assert cue identity, owner, and timing rather than spoken words.

Build through `bin/build_publications.sh`; do not hand-maintain packaged outputs.
