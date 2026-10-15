# Synthetic local newspaper fixture

A synthetic, copyright-clear WebPub with the structure of a Nota local newspaper (Danish "lokalavis"). Real local newspapers have ToC entries that skip-to-next/previous navigation fails on, and they are rights-restricted, so this fixture copies only their structure.

What is kept from the source issue: reading order, ToC nesting, XHTML element nesting, `epub:type`/`role`/`lang`, which elements the ToC and Sync Narration point at, Sync Narration nesting and cue order, and the page list numbers.

What is replaced: all text (`Overskrift e<N>` / `Tekst e<N>.`), ids (`e<N>`), titles (`Sektion 1`, `Artikel 1.1`), metadata, and images (now empty `span`s). The audio says each cue's number in Danish (macOS `say -v Sara`) and is padded to 1.5 seconds per cue, so cue `n` in a file spans `t=(n-1)*1.5,n*1.5`.

## Shape

- 19 XHTML resources, each with its own Sync Narration JSON and MP3 track (305 cues, 457.5 seconds).
- 21 ToC entries, depth 2. 19 top-level entries, one per resource.
- 18 ToC entries point at a `<section>` id that has no cue and is not a Sync Narration container. All cues point at descendants of that section. One more entry has the same shape on an `<aside>`.
- One `h2` ToC entry is itself a cue (`np-0001.xhtml#e4`). One `h1` ToC entry has no cues inside it.
- Two resources have more than one ToC entry: `np-0001.xhtml` and `np-0011.xhtml`.

## Expected ToC owner

| Resource | Time (seconds) | First cue text | Expected ToC owner |
| --- | --- | --- | --- |
| np-0011.xhtml | 0–43.5 | np-0011.xhtml#e168 | np-0011.xhtml#e166 (`section`) |
| np-0011.xhtml | 43.5–48 | np-0011.xhtml#e199 | np-0011.xhtml#e198 (`aside`) |

In every other resource, every cue belongs to that resource's single ToC entry. A player that resolves the owner only by exact cue-id match, or only by the ids that a content iterator reports, finds no owner here. Skip-to-next-ToC then falls back to the reading order.

Build through `bin/build_publications.sh`; do not hand-maintain packaged outputs.
