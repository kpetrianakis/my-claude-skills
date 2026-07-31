# wol-reference-lookup — usage

A Claude Code skill that finds Bible and JW-publication references in text
you paste and fetches their real content from wol.jw.org (never from
memory). See `SKILL.md` in this folder for the technical method Claude
follows; this file is just how to *use* it day to day and how to carry it
to another machine.

## Where it lives

This is a **personal (user-level) skill**, stored at:

```
~/.claude/skills/wol-reference-lookup/
```

Personal skills are available in **every** Claude Code project on a given
machine — not just one repo. That's different from a *project* skill
(`.claude/skills/...` inside a specific repo), which only loads when you're
working inside that repo.

## How to invoke it

Either works:

- **Natural language** — just paste the text and ask, e.g.:
  > "Look up the references in this passage: ..."
  > "Find the Bible verses in this outline, I don't need the publication citations"
  > "Check the citations in this article and give me the actual text"

  Claude matches your request against the skill's description and loads it
  automatically.

- **Explicit invocation** — type `/wol-reference-lookup` followed by your
  text or instructions, e.g.:
  ```
  /wol-reference-lookup mode=bible
  <paste your passage here>
  ```

## Selecting a mode

Say what you want up front, in plain language or via `mode=`:
- `mode=bible` — only resolve scripture citations
- `mode=publications` — only resolve JW-literature citations (w, g, km, mwb, book codes, etc.)
- `mode=both` (default) — resolve everything, including combined citations
  like `Ματ 28:20· w22.07 σ. 9 ¶6-8`

If you don't specify, it defaults to both.

## What you get back

For each reference found, in the order it appeared in your source text:
- The original citation as written
- The resolved text (verse text, or article title + paragraph/page text)
- A clear **"not found"** line for anything that couldn't be resolved on
  WOL — it will never invent or paraphrase content from memory instead.

Cross-references *inside* the resolved text (e.g. a Watchtower paragraph
that itself cites another scripture) are left as plain text — the skill
won't chase them automatically.

## Installing this skill on another machine

This folder is mirrored in `git@github.com:kpetrianakis/my-claude-skills.git`
under `skills/wol-reference-lookup/`. To use it on a different PC:

1. Clone (or `git pull` if already cloned) the repo.
2. Get this folder to land at `~/.claude/skills/wol-reference-lookup/`
   (exact path). Two ways:

   **A. Plain copy** (simplest, works everywhere, no special permissions):
   ```bash
   git clone git@github.com:kpetrianakis/my-claude-skills.git ~/my-claude-skills
   mkdir -p ~/.claude/skills
   cp -r ~/my-claude-skills/skills/wol-reference-lookup ~/.claude/skills/wol-reference-lookup
   ```
   To pick up future updates: `git pull` in `~/my-claude-skills`, then
   re-copy.

   **B. Symlink** (updates automatically with `git pull`, no re-copying):
   - macOS/Linux:
     ```bash
     git clone git@github.com:kpetrianakis/my-claude-skills.git ~/my-claude-skills
     mkdir -p ~/.claude/skills
     ln -s ~/my-claude-skills/skills/wol-reference-lookup ~/.claude/skills/wol-reference-lookup
     ```
   - Windows (PowerShell, run as Administrator, or with Developer Mode
     enabled so symlinks don't require elevation):
     ```powershell
     git clone git@github.com:kpetrianakis/my-claude-skills.git $HOME\my-claude-skills
     New-Item -ItemType SymbolicLink `
       -Path "$HOME\.claude\skills\wol-reference-lookup" `
       -Target "$HOME\my-claude-skills\skills\wol-reference-lookup"
     ```

Either way, once the folder exists at `~/.claude/skills/wol-reference-lookup/`
on that machine, it's available in every project you open there — no
per-project setup needed.

**Note:** this repo's existing `hooks/sync-skills.ps1` only watches
`~/.claude/commands/`, `~/.claude/hooks/`, and `~/.claude/settings.json` for
changes to auto-offer a sync — it does not currently watch `~/.claude/skills/`,
so edits to this skill won't trigger that prompt automatically. Sync manually
(copy back into this repo, commit, push) until/unless the hook is extended.
