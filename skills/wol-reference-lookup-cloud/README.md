# wol-reference-lookup-cloud — usage

The **claude.ai / sandboxed** version of the WOL reference lookup skill.
Finds Bible and JW-publication references in text you paste and retrieves
their content strictly from wol.jw.org.

## Which of the two skills to use where

| Skill | Where | Method |
|---|---|---|
| `wol-reference-lookup` | Claude Code (has a shell) | `curl` + exact HTML parsing. Verified, precise. |
| `wol-reference-lookup-cloud` (this one) | claude.ai web/desktop/mobile | Site-restricted search + limited fetching. Less exact by necessity. |

Keep the Claude Code one installed locally under `~/.claude/skills/`, and
upload only this one to claude.ai. That way each environment has exactly one
skill and they can't be confused with each other.

## Why a separate skill instead of one that adapts

claude.ai imposes two hard limits that make the Claude Code method impossible
there, not merely slower:

1. **Fetching is provenance-gated.** The fetch tool only accepts URLs that
   already appeared in a search result or that you pasted into the chat. A
   constructed WOL chapter URL is refused, so the "build the URL and fetch it"
   approach the local skill relies on cannot work.
2. **Search covers the whole web.** Left unconstrained it returns other Bible
   sites and translations. This skill forces `site:wol.jw.org` on every search
   and discards anything not from that host.

Trying to serve both environments from one file made the instructions longer,
more expensive to load, and worse at both jobs — hence two skills.

## How to invoke it

Paste your text and ask, e.g.:
> "Look up the references in this outline"
> "Find just the Bible verses in this passage"

Or explicitly: `/wol-reference-lookup-cloud`

Modes: `bible`, `publications`, or `both` (default).

## What to expect — honestly

This method is **less reliable than the Claude Code version**, by design
constraint rather than lack of care:

- It works best when WOL's own search snippets contain the verse or paragraph
  text, which is common but not guaranteed.
- Each reference gets **one search, plus one fetch** if a WOL URL surfaced.
  If that doesn't resolve it, it's marked unresolved and the skill moves on
  rather than burning many calls chasing it.
- Expect a mix: some references fully resolved, some marked unresolved. Every
  run ends with a status table so the gaps are explicit.

**It will never fill a gap with a guess.** If WOL doesn't yield the text, you
get "not found" — not a remembered paraphrase, not the same verse from another
Bible site, and not an English verse standing in for a Greek citation.

If several references come back unresolved and you need them, the reliable
fallback is to run the same text through the Claude Code skill instead, or to
paste the specific WOL page URLs into the chat — user-pasted URLs bypass the
fetch restriction and can be read directly.

## Installing / updating

Mirrored in `git@github.com:kpetrianakis/my-claude-skills.git` under
`skills/wol-reference-lookup-cloud/`.

To upload to claude.ai: zip this folder (with the folder itself as the zip
root), then go to **claude.ai → Settings → Capabilities → Skills** and upload.

```powershell
Compress-Archive -Path "$HOME\.claude\skills\wol-reference-lookup-cloud" `
  -DestinationPath "$HOME\wol-reference-lookup-cloud.zip" -Force
```

Re-zip and re-upload after any edit — claude.ai holds its own copy, and there
is no export path back out of it, so this repo stays the source of truth.
