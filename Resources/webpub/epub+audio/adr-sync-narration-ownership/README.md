# Sync Narration ownership regression fixture

A synthetic, copyright-clear WebPub for flutter_readium ADR 0001. Text and audio
were authored for these tests. A quiet generated tone provides a real 22-second
MP3 timeline; every cue references that one track.

| Time (seconds) | Text target | Expected ToC owner |
| --- | --- | --- |
| 0–2 | one.xhtml#intro | one.xhtml#parent |
| 2–4 | one.xhtml#heading-a | one.xhtml#heading-a |
| 4–6 | one.xhtml#heading-b | one.xhtml#heading-b |
| 6–8 | one.xhtml#paragraph-b | one.xhtml#heading-b |
| 8–10 | one.xhtml#after-wrapper | one.xhtml#heading-a |
| 10–12 | one.xhtml#inside-section | one.xhtml#shared-section |
| 12–14 | one.xhtml#after-container | one.xhtml#heading-a |
| 14–16 | two.xhtml#boundary | two.xhtml |
| 16–18 | two.xhtml#inside-section | two.xhtml#shared-section |
| 18–22 | two.xhtml#after-boundary | two.xhtml |

The narration list crosses into the second text resource while still grouped
under the first resource's parent. Such cross-resource grouping is observed in
TestResources; this synthetic version uses one audio track to test ownership
without depending on deferred iOS multi-audio reading-order support.

Both resources contain an audio-less `shared-section`, so structural seeking
must distinguish the resource as well as the fragment. The generic wrapper and
nested container must restore the caller's active heading A, not the parent.

Build through `bin/build_publications.sh`; do not hand-maintain packaged outputs.
To reproduce the audio:

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:sample_rate=22050:duration=22' \
  -af volume=0.01 -codec:a libmp3lame -b:a 32k track.mp3
```
